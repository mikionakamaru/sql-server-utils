/*
Arquivo: index-defrag.sql
Autor: Mikio Nakamaru
Descrição: Script para identificar e desfragmentar índices em tabelas do banco de dados atual.
Utiliza DBCC SHOWCONTIG para medir fragmentação e DBCC INDEXDEFRAG para realizar a desfragmentação
apenas em índices cuja fragmentação ultrapassa o limite configurado (10% por padrão).
*/

SET NOCOUNT ON;

DECLARE @tablename VARCHAR(255);
DECLARE @execstr VARCHAR(400);
DECLARE @objectid INT;
DECLARE @indexid INT;
DECLARE @frag DECIMAL;
DECLARE @maxfrag DECIMAL;

-- Define o limite máximo de fragmentação aceitável (10%)
SELECT @maxfrag = 10.0;

-- Cursor para percorrer todas as tabelas base do banco
DECLARE tables CURSOR FOR
   SELECT TABLE_SCHEMA + '.' + TABLE_NAME
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_TYPE = 'BASE TABLE';

-- Criação da tabela temporária para armazenar resultados do DBCC SHOWCONTIG
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

-- Abre o cursor de tabelas
OPEN tables;

-- Loop para coletar dados de fragmentação por tabela
FETCH NEXT FROM tables INTO @tablename;

WHILE @@FETCH_STATUS = 0
BEGIN
   -- Executa o DBCC SHOWCONTIG para todos os índices da tabela atual e insere o resultado em #fraglist
   INSERT INTO #fraglist 
   EXEC ('DBCC SHOWCONTIG (''' + @tablename + ''') WITH FAST, TABLERESULTS, ALL_INDEXES, NO_INFOMSGS');
   
   FETCH NEXT FROM tables INTO @tablename;
END;

-- Fecha e desaloca cursor de tabelas
CLOSE tables;
DEALLOCATE tables;

-- Cursor para percorrer os índices cuja fragmentação ultrapassa o limite e podem ser desfragmentados
DECLARE indexes CURSOR FOR
   SELECT ObjectName, ObjectId, IndexId, LogicalFrag
   FROM #fraglist
   WHERE LogicalFrag >= @maxfrag
     AND INDEXPROPERTY(ObjectId, IndexName, 'IndexDepth') > 0;

OPEN indexes;

FETCH NEXT FROM indexes INTO @tablename, @objectid, @indexid, @frag;

WHILE @@FETCH_STATUS = 0
BEGIN
   PRINT 'Executando DBCC INDEXDEFRAG (0, ' + RTRIM(@tablename) + ', '
       + RTRIM(CONVERT(VARCHAR, @indexid)) + ') - fragmentação atual '
       + RTRIM(CONVERT(VARCHAR(15), @frag)) + '%';

   SET @execstr = 'DBCC INDEXDEFRAG (0, ' + RTRIM(CONVERT(VARCHAR, @objectid)) + ', ' + RTRIM(CONVERT(VARCHAR, @indexid)) + ')';
    
   EXEC (@execstr);

   FETCH NEXT FROM indexes INTO @tablename, @objectid, @indexid, @frag;
END;

-- Fecha e desaloca cursor de índices
CLOSE indexes;
DEALLOCATE indexes;

-- Remove tabela temporária
DROP TABLE #fraglist;
GO
