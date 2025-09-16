-- View vw_customer_loan_summary: hiển thị tổng dư nợ, tổng lãi, tổng phạt của mỗi khách hàng.
CREATE VIEW vư_customer_loan_summary AS
SELECT 
    a.customer_id,
    a.full_name,
    SUM(CASE WHEN b.status <> 'closed' THEN b.loan_amount ELSE 0 END) AS total_principal,
    SUM(CASE WHEN b.status <> 'closed' 
             THEN b.loan_amount * (b.interest_rate / 100.0) 
             ELSE 0 END) AS total_interest,
    ISNULL(SUM(c.penalty_amount), 0) AS total_penalty
FROM bank_customers a
LEFT JOIN bank_loan_accounts b
       ON a.customer_id = b.customer_id
LEFT JOIN bank_penalties c 
       ON b.loan_id = c.loan_id
GROUP BY 
    a.customer_id, 
    a.full_name

-- View vw_overdue_loans: liệt kê toàn bộ khoản vay đang quá hạn, kèm số ngày trễ hạn.
CREATE VIEW vw_overdue_loans AS
SELECT 
    a.loan_id,
    a.customer_id,
    b.full_name,
    a.loan_type,
    a.loan_amount,
    a.start_date,
    a.due_date,
    a.status,
    DATEDIFF(DAY, a.due_date, GETDATE()) AS days_overdue
FROM bank_loan_accounts a
INNER JOIN bank_customers b 
        ON a.customer_id = b.customer_id
WHERE 
    a.status = 'overdue'
    OR (a.status <> 'closed' AND a.due_date < GETDATE());

-- Materialized View mv_daily_balance: tổng hợp dư nợ (outstanding balance) 
-- theo từng ngày để tối ưu query dashboard.
CREATE VIEW mv_daily_balance
WITH SCHEMABINDING
AS
SELECT 
    la.loan_id,
    la.customer_id,
    CONVERT(DATE, t.transaction_date) AS balance_date,
    SUM(CASE 
            WHEN t.transaction_type = 'disbursement' THEN t.amount
            WHEN t.transaction_type = 'repayment'    THEN -t.amount
            ELSE 0
        END) AS net_change,
    COUNT_BIG(*) AS cnt
FROM dbo.bank_loan_accounts la
JOIN dbo.bank_transactions t
     ON la.loan_id = t.loan_id
GROUP BY 
    la.loan_id,
    la.customer_id,
    CONVERT(DATE, t.transaction_date)
GO

CREATE UNIQUE CLUSTERED INDEX ix_mv_daily_balance 
    ON mv_daily_balance(loan_id, balance_date)

-- Materialized View mv_penalty_analysis: tổng hợp số tiền phạt theo loan_type và theo tháng.
CREATE VIEW mv_penalty_analysis
WITH SCHEMABINDING
AS
SELECT 
    la.loan_type,
    YEAR(p.applied_date) AS penalty_year,
    MONTH(p.applied_date) AS penalty_month,
    SUM(p.penalty_amount) AS total_penalty,
    COUNT_BIG(*) AS cnt
FROM dbo.bank_penalties p
JOIN dbo.bank_loan_accounts la
     ON p.loan_id = la.loan_id
GROUP BY la.loan_type, YEAR(p.applied_date), MONTH(p.applied_date)
GO

CREATE UNIQUE CLUSTERED INDEX ix_mv_penalty_analysis
    ON mv_penalty_analysis(loan_type, penalty_year, penalty_month)