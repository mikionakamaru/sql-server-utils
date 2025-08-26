/*
    Arquivo: sql-server-administration-queries.sql
    Autor: Mikio Nakamaru
    Descrição: Conjunto de consultas úteis para administração do SQL Server.
    Cada bloco pode ser executado separadamente para obter informações específicas.
    ------------------------------------------------------------------------------------------------
*/

-- Consulta 1: Exibe a versão completa do SQL Server instalado
SELECT @@version;
GO

-- Consulta 2: Exibe o nível de isolamento e se o snapshot está ativado em cada banco de dados
SELECT name, is_read_committed_snapshot_on FROM sys.databases;
GO

/*
Consulta 3: Verifica a fragmentação dos índices em uso no banco atual
- Cria uma tabela temporária para armazenar resultados do DBCC SHOWCONTIG
- Executa o DBCC SHOWCONTIG para coletar dados de fragmentação
- Exibe os dados ordenados por número de páginas para análise 
- Remove a tabela temporária ao final da execução
*/
IF OBJECT_ID('tempdb..#fraglist') IS NOT NULL DROP TABLE #fraglist;

CREATE TABLE #fraglist (
    ObjectName CHAR(255),
    ObjectId INT,
    IndexName CHAR(255),
    IndexId INT,
    Lvl INT,
    CountPages INT,
    CountRows INT,
    MinRecSize INT,
    MaxRecSize INT,
    AvgRecSize INT,
    ForRecCount INT,
    Extents INT,
    ExtentSwitches INT,
    AvgFreeBytes INT,
    AvgPageDensity INT,
    ScanDensity DECIMAL(10,2),
    BestCount INT,
    ActualCount INT,
    LogicalFrag DECIMAL(10,2),
    ExtentFrag DECIMAL(10,2)
);

INSERT INTO #fraglist 
EXEC ('DBCC SHOWCONTIG WITH TABLERESULTS');
GO

SELECT * FROM #fraglist ORDER BY CountPages DESC;
GO

DROP TABLE #fraglist;
GO

-- Consulta 4: Exibe a quantidade de tabelas conforme tipo de escalonamento de lock para SQL Server 2008 ou superior
SELECT lock_escalation_desc, COUNT(1) AS QTE FROM sys.tables GROUP BY lock_escalation_desc;
GO

-- Consulta 5: Exibe a quantidade de tabelas conforme tipo de escalonamento de lock para SQL Server 2005
SELECT type_desc, COUNT(1) AS QTE FROM sys.tables GROUP BY type_desc;
GO

-- Consulta 6: Mostra a última data de backup realizada para cada banco de dados
SELECT database_name, MAX(backup_finish_date) AS backup_finish_date 
FROM msdb.dbo.backupset 
GROUP BY database_name 
ORDER BY backup_finish_date DESC;
GO

/*
Consulta 7: Lista as 10 maiores tabelas do banco por espaço ocupado (KB)
- Exclui tabelas do sistema e as internas do banco msdb e similares
- Mostra nome da tabela, número de registros e espaço total, usado e não usado em KB
*/
SELECT TOP 10
    t.NAME AS Entidade,
    p.rows AS Registros,
    SUM(a.total_pages) * 8 AS EspacoTotalKB,
    SUM(a.used_pages) * 8 AS EspacoUsadoKB,
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS EspacoNaoUsadoKB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.NAME NOT LIKE 'dt%' 
  AND t.is_ms_shipped = 0 
  AND i.OBJECT_ID > 255
GROUP BY t.Name, s.Name, p.Rows
ORDER BY EspacoTotalKB DESC;
GO
