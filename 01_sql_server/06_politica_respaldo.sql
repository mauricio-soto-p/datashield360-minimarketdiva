/* =====================================================================
   SCRIPT 06 : Política de respaldo y recuperación (Paso 3)
   ---------------------------------------------------------------------
   Estrategia (RPO <= 15 min, RTO <= 1 h) adaptada al horario de la
   licorería (09:00-24:00, picos viernes y sábado de 19:00 a 24:00):
     FULL          : lunes 06:00 (día de menor venta)  retención 4 semanas
     DIFERENCIAL   : martes a domingo 06:00            retención 2 semanas
     LOG (T-LOG)   : cada 15 min de 09:00 a 23:59       retención 7 días
     + copia externa (regla 3-2-1): disco local + NAS + nube
   Requisitos: modelo de recuperación FULL (script 01). La compresión de
   backup NO está disponible en SQL Server Express: quite COMPRESSION ahí.
   Ajuste @Carpeta a una ruta existente con permisos para el servicio.
   ===================================================================== */
USE master;
GO

/* ---------- 0. Verificación del modelo de recuperación ---------- */
SELECT name, recovery_model_desc FROM sys.databases WHERE name = N'MinimarketDiva';   -- debe decir FULL
GO

/* ---------- 1. Procedimiento parametrizado de respaldo ---------- */
CREATE OR ALTER PROCEDURE dbo.usp_RespaldoDiva
    @Tipo    VARCHAR(4),                                   -- 'FULL' | 'DIFF' | 'LOG'
    @Carpeta NVARCHAR(200) = N'C:\Backups\MinimarketDiva'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @archivo NVARCHAR(400), @sql NVARCHAR(MAX),
            @marca   VARCHAR(15) = FORMAT(SYSDATETIME(), 'yyyyMMdd_HHmm');

    BEGIN TRY
        IF @Tipo NOT IN ('FULL','DIFF','LOG')
            THROW 50200, 'Tipo de backup inválido.', 1;

        -- Nombre de archivo con tipo y fecha: facilita la cadena de restauración
        SET @archivo = @Carpeta + N'Diva_' + @Tipo + N'_' + @marca
                     + CASE WHEN @Tipo = 'LOG' THEN N'.trn' ELSE N'.bak' END;

        SET @sql = CASE @Tipo
            WHEN 'FULL' THEN N'BACKUP DATABASE MinimarketDiva TO DISK = @f WITH INIT, COMPRESSION, CHECKSUM, '
                           + N'NAME = N''Full semanal'', STATS = 10;'
            WHEN 'DIFF' THEN N'BACKUP DATABASE MinimarketDiva TO DISK = @f WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, '
                           + N'NAME = N''Diferencial diario'', STATS = 10;'
            WHEN 'LOG'  THEN N'BACKUP LOG MinimarketDiva TO DISK = @f WITH INIT, COMPRESSION, CHECKSUM, '
                           + N'NAME = N''Log cada 15 min'';'
        END;
        EXEC sys.sp_executesql @sql, N'@f NVARCHAR(400)', @f = @archivo;

        -- Verificación de integridad del archivo generado (sin restaurar)
        RESTORE VERIFYONLY FROM DISK = @archivo WITH CHECKSUM;

        PRINT CONCAT('Backup ', @Tipo, ' OK y verificado: ', @archivo);
    END TRY
    BEGIN CATCH
        PRINT CONCAT('FALLA DE BACKUP ', @Tipo, ': ', ERROR_MESSAGE());
        THROW;   -- el Agente marca el job como fallido y notifica al operador
    END CATCH
END;
GO

/* ---------- 2. Ejecución manual de la cadena (para evidencia en laboratorio) ---------- */
EXEC dbo.usp_RespaldoDiva @Tipo = 'FULL';
-- ... se simulan transacciones ...
EXEC dbo.usp_RespaldoDiva @Tipo = 'DIFF';
EXEC dbo.usp_RespaldoDiva @Tipo = 'LOG';
GO

/* ---------- 3. Historial de respaldos (evidencia de cumplimiento) ---------- */
SELECT TOP (20)
       bs.database_name, bs.backup_start_date, bs.backup_finish_date,
       CASE bs.type WHEN 'D' THEN 'FULL' WHEN 'I' THEN 'DIFERENCIAL' WHEN 'L' THEN 'LOG' END AS Tipo,
       CAST(bs.backup_size / 1048576.0 AS DECIMAL(10,2))            AS TamanoMB,
       CAST(bs.compressed_backup_size / 1048576.0 AS DECIMAL(10,2)) AS ComprimidoMB,
       bmf.physical_device_name
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bmf.media_set_id = bs.media_set_id
WHERE bs.database_name = N'MinimarketDiva'
ORDER BY bs.backup_start_date DESC;
GO

/* ---------- 4. Automatización con SQL Server Agent (no disponible en Express) ----------
   Se crean 3 jobs con sus horarios. En Express se reemplaza por el
   Programador de tareas de Windows + sqlcmd -Q "EXEC master.dbo.usp_RespaldoDiva 'FULL'". */
USE msdb;
GO
DECLARE @jobs TABLE (Nombre SYSNAME, Tipo VARCHAR(4), FreqType INT, FreqInterval INT, SubdayType INT, SubdayInterval INT, HoraInicio INT, HoraFin INT);
INSERT INTO @jobs VALUES
 (N'Diva - Backup FULL semanal',  'FULL', 8, 2,  1, 0,  60000, 235959),    -- semanal, lunes (2), 06:00
 (N'Diva - Backup DIFF diario',   'DIFF', 8, 125,1, 0,  60000, 235959),    -- mar-dom (4+8+16+32+64+1)
 (N'Diva - Backup LOG 15 min',    'LOG',  4, 1,  4, 15, 90000, 235900);    -- diario, cada 15 min 09:00-23:59

DECLARE @n SYSNAME, @t VARCHAR(4), @ft INT, @fi INT, @st INT, @si INT, @hi INT, @hf INT, @cmd NVARCHAR(200);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @jobs;
OPEN c; FETCH NEXT FROM c INTO @n, @t, @ft, @fi, @st, @si, @hi, @hf;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @n) EXEC msdb.dbo.sp_delete_job @job_name = @n;
    SET @cmd = N'EXEC master.dbo.usp_RespaldoDiva @Tipo = ''' + @t + N''';';
    EXEC msdb.dbo.sp_add_job        @job_name = @n, @description = N'Política de respaldo DataShield 360 - Minimarket Diva';
    EXEC msdb.dbo.sp_add_jobstep    @job_name = @n, @step_name = N'Ejecutar backup', @subsystem = N'TSQL',
                                    @database_name = N'master', @command = @cmd, @retry_attempts = 2, @retry_interval = 5;
    EXEC msdb.dbo.sp_add_jobschedule @job_name = @n, @name = @n, @enabled = 1,
                                    @freq_type = @ft, @freq_interval = @fi, @freq_recurrence_factor = 1,
                                    @freq_subday_type = @st, @freq_subday_interval = @si,
                                    @active_start_time = @hi, @active_end_time = @hf;
    EXEC msdb.dbo.sp_add_jobserver  @job_name = @n, @server_name = N'(local)';
    FETCH NEXT FROM c INTO @n, @t, @ft, @fi, @st, @si, @hi, @hf;
END
CLOSE c; DEALLOCATE c;
SELECT name, enabled, date_created FROM msdb.dbo.sysjobs WHERE name LIKE N'Diva - Backup%';
GO

/* ---------- 5. PROCEDIMIENTO DE RECUPERACIÓN (simulacro de desastre) ----------
   Escenario: el sábado 21:40 (hora pico) un UPDATE sin WHERE altera precios.
   Se dispone de: FULL (lunes) + DIFF (sábado 06:00) + LOGs del sábado hasta 21:30.
   Pasos:
   (1) Backup del "tail log" para no perder lo último (NORECOVERY deja la BD en restauración)
   (2) Restaurar FULL  WITH NORECOVERY
   (3) Restaurar DIFF  WITH NORECOVERY  (solo el último diferencial)
   (4) Restaurar LOGs en orden WITH NORECOVERY; el último con STOPAT justo antes del error
   (5) RECOVERY -> la base queda en línea. Validar con DBCC CHECKDB.
   Reemplace los nombres de archivo por los generados en su laboratorio.          */
USE master;
GO
/*
BACKUP LOG MinimarketDiva TO DISK = N'C:\Backups\MinimarketDiva\Diva_TAIL.trn' WITH NORECOVERY, CHECKSUM;

RESTORE DATABASE MinimarketDiva FROM DISK = N'C:\Backups\MinimarketDiva\Diva_FULL_20261109_0600.bak'
        WITH NORECOVERY, REPLACE, STATS = 10;
RESTORE DATABASE MinimarketDiva FROM DISK = N'C:\Backups\MinimarketDiva\Diva_DIFF_20261114_0600.bak'
        WITH NORECOVERY, STATS = 10;
RESTORE LOG MinimarketDiva FROM DISK = N'C:\Backups\MinimarketDiva\Diva_LOG_20261114_2115.trn' WITH NORECOVERY;
RESTORE LOG MinimarketDiva FROM DISK = N'C:\Backups\MinimarketDiva\Diva_LOG_20261114_2130.trn' WITH NORECOVERY;
RESTORE LOG MinimarketDiva FROM DISK = N'C:\Backups\MinimarketDiva\Diva_TAIL.trn'
        WITH STOPAT = '2026-11-14T21:39:00', RECOVERY;      -- recuperación a un punto en el tiempo

DBCC CHECKDB (MinimarketDiva) WITH NO_INFOMSGS;      -- integridad física y lógica
*/

-- Alternativa de prueba SIN afectar la base original: restaurar como copia
/*
RESTORE DATABASE MinimarketDiva_PRUEBA
FROM DISK = N'C:\Backups\MinimarketDiva\Diva_FULL_20261109_0600.bak'
WITH MOVE N'MinimarketDiva_Data' TO N'C:\Backups\MinimarketDiva\Prueba.mdf',   -- nombres lógicos del script 00a
     MOVE N'MinimarketDiva_Sec'  TO N'C:\Backups\MinimarketDiva\Prueba.ndf',
     MOVE N'MinimarketDiva_Log'  TO N'C:\Backups\MinimarketDiva\Prueba_log.ldf',
     RECOVERY, STATS = 10;
SELECT COUNT(*) AS VentasRestauradas FROM MinimarketDiva_PRUEBA.dbo.Venta;   -- esperado 75,043 + ventas de prueba
*/
GO

-- Nombres lógicos de los archivos (necesarios para MOVE)
SELECT name AS NombreLogico, physical_name, type_desc
FROM sys.master_files WHERE database_id = DB_ID(N'MinimarketDiva');
GO
