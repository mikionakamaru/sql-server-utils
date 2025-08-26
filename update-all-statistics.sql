-- Script para atualizar estatísticas em todas as tabelas do banco atual no SQL Server
-- Atualiza automaticamente apenas as estatísticas que precisam ser atualizadas, otimizando consultas
-- Útil para manutenção periódica, especialmente após grandes alterações em dados
-- Permissões necessárias: sysadmin ou dono do banco de dados

exec sp_updatestats;  -- Executa a atualização das estatísticas para todas as tabelas no banco atual
