CREATE DATABASE MinimarketDiva
ON 
PRIMARY
(   /* Creación de los archivos en donde se guardará la base de datos */
    NAME = MinimarketDiva_Data,
    FILENAME = 'D:\MinimarketDiva.mdf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
),
FILEGROUP DatosSecundarios
(
    NAME = MinimarketDiva_Sec,
    FILENAME = 'D:\MinimarketDiva.ndf',
    SIZE = 5MB,
    MAXSIZE = 50MB,
    FILEGROWTH = 5MB
)
LOG ON
(
    NAME = MinimarketDiva_Log,
    FILENAME = 'D:\MinimarketDiva.ldf',
    SIZE = 5MB,
    MAXSIZE = 25MB,
    FILEGROWTH = 5MB
);
GO

USE MinimarketDiva
GO