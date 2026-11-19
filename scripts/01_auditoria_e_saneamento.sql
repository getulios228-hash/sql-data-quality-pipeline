-- ============================================================================
-- PROJETO: PIPELINE DE AUDITORIA E DATA QUALITY EM BASES RELACIONAIS
-- AUTOR: Getúlio Alves da Silva
-- DESCRIÇÃO: Profiling, deduplicação, tratamento de anomalias e View Gold
-- ============================================================================

-- 1. PROFILING INICIAL: DIAGNÓSTICO DE SAÚDE DA BASE BRUTA
SELECT 
    COUNT(*) AS total_linhas_brutas,
    COUNT(DISTINCT id_registro) AS ids_unicos,
    SUM(CASE WHEN cpf_paciente IS NULL OR TRIM(cpf_paciente) = '' THEN 1 ELSE 0 END) AS cpfs_nulos,
    SUM(CASE WHEN data_solicitacao IS NULL THEN 1 ELSE 0 END) AS datas_nulas,
    SUM(CASE WHEN data_execucao < data_solicitacao THEN 1 ELSE 0 END) AS datas_invertidas
FROM raw_regulacao_atendimentos;

-- 2. LIMPEZA E PADRONIZAÇÃO (CAMADA STAGING)
CREATE OR REPLACE VIEW stg_regulacao_limpa AS
SELECT 
    id_registro,
    REGEXP_REPLACE(TRIM(cpf_paciente), '[^0-9]', '', 'g') AS cpf_limpo,
    UPPER(TRIM(nome_paciente)) AS nome_padronizado,
    UPPER(TRIM(codigo_procedimento)) AS codigo_procedimento,
    UPPER(TRIM(complexidade)) AS complexidade,
    UPPER(TRIM(status_fila)) AS status_fila,
    data_solicitacao,
    CASE 
        WHEN data_execucao < data_solicitacao THEN NULL 
        ELSE data_execucao 
    END AS data_execucao_validada,
    sla_dias_meta,
    data_atualizacao
FROM raw_regulacao_atendimentos
WHERE cpf_paciente IS NOT NULL 
  AND LENGTH(REGEXP_REPLACE(TRIM(cpf_paciente), '[^0-9]', '', 'g')) = 11;

-- 3. DEDUPLICAÇÃO E CONSTRUÇÃO DA CAMADA ANALÍTICA (GOLD LAYER)
CREATE OR REPLACE VIEW gold_atendimentos_saneados AS
WITH deduplicacao AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY cpf_limpo, codigo_procedimento, DATE(data_solicitacao)
            ORDER BY data_atualizacao DESC, id_registro DESC
        ) AS rn
    FROM stg_regulacao_limpa
)
SELECT 
    id_registro,
    cpf_limpo,
    nome_padronizado,
    codigo_procedimento,
    complexidade,
    status_fila,
    data_solicitacao,
    data_execucao_validada,
    sla_dias_meta,
    CASE 
        WHEN status_fila = 'CONCLUIDO' AND data_execucao_validada IS NOT NULL 
            THEN EXTRACT(DAY FROM (data_execucao_validada - data_solicitacao))
        WHEN status_fila = 'PENDENTE' 
            THEN EXTRACT(DAY FROM (CURRENT_DATE - data_solicitacao))
        ELSE NULL
    END AS dias_espera_real,
    CASE 
        WHEN status_fila = 'CONCLUIDO' 
             AND EXTRACT(DAY FROM (data_execucao_validada - data_solicitacao)) <= sla_dias_meta 
            THEN 'DENTRO DO SLA'
        WHEN status_fila = 'CONCLUIDO' 
             AND EXTRACT(DAY FROM (data_execucao_validada - data_solicitacao)) > sla_dias_meta 
            THEN 'FORA DO SLA'
        ELSE 'EM ANDAMENTO'
    END AS indicador_sla
FROM deduplicacao
WHERE rn = 1;

-- 4. RELATÓRIO EXECUTIVO DE AUDITORIA PARA BI
SELECT 
    complexidade,
    indicador_sla,
    COUNT(*) AS volume_atendimentos,
    ROUND(AVG(dias_espera_real), 1) AS media_dias_espera
FROM gold_atendimentos_saneados
GROUP BY complexidade, indicador_sla
ORDER BY complexidade, volume_atendimentos DESC;
