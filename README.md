# 🔍 Pipeline de Auditoria e Saneamento de Dados (SQL + Data Quality)

![Status](https://shields.io)
![SQL](https://shields.io)
![Data Quality](https://shields.io)
![BI](https://shields.io)

> **Estudo de caso prático de Engenharia e Governança de Dados:** rotinas estruturadas em SQL para detecção de anomalias, deduplicação de registros e saneamento de bases relacionais críticas antes da camada de Business Intelligence.

---

### 🎯 1. Contexto e Problema de Negócio (Situação & Tarefa)

Em operações de grande volume (como regulação de saúde pública, saneamento ou logística), bases transacionais acumuladas ao longo de anos sofrem com degradação cadastral:
* **Registros duplicados** gerados por múltiplas entradas manuais sem chave única padronizada.
* **Inconsistências de status e datas** (ex.: atendimentos concluídos antes da data de solicitação ou filas abertas com pacientes já atendidos).
* **Distorção nos indicadores executivos (KPIs)** e falhas no controle de **SLAs**, comprometendo a tomada de decisão da diretoria.

**Objetivo do projeto:** Construir uma camada automatizada de **Data Quality** em SQL capaz de auditar uma base relacional com mais de **250.000 registros**, isolar inconsistências e entregar uma visão analítica confiável (*Gold Layer*) para consumo direto no Power BI.

---

### ⚙️ 2. Arquitetura do Pipeline de Saneamento (Ação)

O fluxo foi desenhado em **4 etapas sequenciais** utilizando Common Table Expressions (`CTEs`), *Window Functions* e regras de negócio auditáveis:

```text
[Camada Raw / Transacional] (250k+ registros brutos)
       │
       ▼
[1. Profiling & Diagnóstico] ──► Contagem de nulos, formatos inválidos e outliers temporais
       │
       ▼
[2. Deduplicação Inteligente] ──► Window Functions (ROW_NUMBER) priorizando o registro mais recente/completo
       │
       ▼
[3. Saneamento & Regras de Negócio] ──► Padronização de chaves, status e cálculo real de SLA
       │
       ▼
[Camada Gold / Analytics] ──► View materializada pronta para Power BI + Log de Auditoria
```

---

### 💻 3. Exemplos de Scripts SQL Aplicados

Abaixo estão trechos representativos das regras implementadas no arquivo [`scripts/01_auditoria_e_saneamento.sql`](scripts/01_auditoria_e_saneamento.sql):

#### 🔹 Deduplicação com Preservação do Histórico Mais Recente (`Window Functions`)
```sql
WITH base_ranqueada AS (
    SELECT 
        id_registro,
        cpf_paciente,
        codigo_procedimento,
        data_solicitacao,
        status_fila,
        ROW_NUMBER() OVER (
            PARTITION BY cpf_paciente, codigo_procedimento, DATE(data_solicitacao)
            ORDER BY data_atualizacao DESC, id_registro DESC
        ) AS ranking_duplicidade
    FROM stg_regulacao_atendimentos
    WHERE cpf_paciente IS NOT NULL
)
SELECT *
FROM base_ranqueada
WHERE ranking_duplicidade = 1;
```

#### 🔹 Auditoria de Anomalias Temporais e Cálculo Real de SLA
```sql
SELECT 
    unidade_executante,
    complexidade,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN data_execucao < data_solicitacao THEN 1 ELSE 0 END) AS erro_cronologico,
    ROUND(
        AVG(CASE WHEN status_fila = 'CONCLUIDO' 
            THEN EXTRACT(DAY FROM (data_execucao - data_solicitacao)) END), 1
    ) AS tempo_medio_espera_dias
FROM gold_atendimentos_saneados
GROUP BY unidade_executante, complexidade
ORDER BY erro_cronologico DESC;
```

---

### 📈 4. Resultados e Impacto Operacional (Resultado)

A aplicação sistemática destas regras de *Data Quality* em cenários reais de alta volumetria permite:
* **Saneamento massivo de bases:** Identificação e tratamento de dezenas de milhares de inconsistências cadastrais e duplicidades em bases acima de **250 mil registros**.
* **Visibilidade real de gargalos:** Separação clara entre demandas de baixa, média e alta complexidade, permitindo atuação preventiva na redução do absenteísmo.
* **Confiabilidade executiva:** Garantia de que os painéis gerenciais em Power BI reflitam a realidade operacional, sustentando índices de cumprimento de **SLAs acima de 60%** em filas críticas.

---

### 🗂️ Estrutura do Repositório

```text
sql-data-quality-pipeline/
├── README.md                              # Documentação executiva do case (Método STAR)
└── scripts/
    └── 01_auditoria_e_saneamento.sql      # Queries completas de profiling, deduplicação e view analítica
```

---

### 👤 Autor

**Getúlio Alves da Silva**  
*Coordenador de Dados & BI | Product Owner (Dados & IA) | Governança de TI e IA (ISO/IEC 42001)*  
[![LinkedIn](https://shields.io)](https://linkedin.com)

