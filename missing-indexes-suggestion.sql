/*
    Script: Index Suggestion Generator
    Autor: Mikio Nakamaru
    Descrição: Este script identifica índices ausentes no SQL Server com potencial de otimização,
    calcula o impacto de cada sugestão e gera instruções SQL para criação dos índices recomendados.

    Extensão: 
    - Pode ser adaptado para monitoramentos periódicos, integrando o resultado a dashboards de performance.
    - Recomenda-se avaliar cada sugestão junto às equipes de DBA antes de implementar índices em produção.
*/

SELECT 
    -- Exibe a data/hora da execução do script
    CONVERT(varchar, getdate(), 126) AS runtime,    

    -- Identificadores dos grupos e dos índices ausentes
    mig.index_group_handle, 
    mid.index_handle,

    -- Métrica de melhoria calculada para priorização das sugestões
    CONVERT(decimal(28,1), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) AS improvement_measure,

    -- Sugestão SQL para criação do índice diretamente utilizável
    'CREATE INDEX index_' + CONVERT(varchar, mig.index_group_handle) + '_' + CONVERT(varchar, mid.index_handle)
        + ' ON ' + mid.statement
        + ' (' + ISNULL(mid.equality_columns,'')
        + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END + ISNULL(mid.inequality_columns, '')
        + ')'
        + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement,

    -- Exibe métricas detalhadas e identificadores envolvidos
    migs.*, mid.database_id, mid.[object_id]

FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle

WHERE
    -- Filtro para exibir apenas sugestões com impacto relevante (> 10)
    CONVERT(decimal (28,1), migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) > 10

ORDER BY
    -- Prioriza sugestões com maior potencial de melhoria de performance
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC

PRINT ''
GO
