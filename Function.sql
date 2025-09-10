KIỂM TRA HÀM CÓ TỒN TẠI:
SELECT * 
FROM sys.objects 
WHERE type = 'FN' 
  AND name = 'fn_total_penalty_by_type';

# # NHÓM 1 - LÃI & PHẠT 

--Tổng số tiền lãi mà khách hàng đã trả trong 1 năm
CREATE OR ALTER FUNCTION fn_total_interest_paid
(	@customer_id INT,
	@year INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
DECLARE @total_interest DECIMAL(18,2);
SELECT  @total_interest = ISNULL(SUM(amount),0)
FROM bank_transactions a
JOIN bank_loan_accounts b ON a.loan_id = b.loan_id
WHERE	a.transaction_type = 'interest'
		AND b.customer_id = @customer_id
		AND YEAR(a.transaction_date) = @year
RETURN @total_interest;
END;
GO
--CHECK: 
SELECT fn_total_interest_paid(619, 2024) AS TotalInterest

-- Tổng số tiền phạt theo loại (late fee, prepayment fee) trong 1 năm
CREATE OR ALTER FUNCTION fn_total_penalty_by_type
(
    @customer_id INT,
    @penalty_type NVARCHAR(50),
    @year INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
DECLARE @total_penalty DECIMAL(18,2);
SELECT @total_penalty = ISNULL(SUM(p.penalty_amount), 0)
FROM penalties p
INNER JOIN loan_accounts l ON p.loan_id = l.loan_id
WHERE l.customer_id = @customer_id
      AND p.penalty_type = @penalty_type
      AND YEAR(p.applied_date) = @year;
RETURN @total_penalty;
END;
GO
--CHECK 
SELECT dbo.fn_total_penalty_by_type(619, 'late_fee', 2024) AS TotalLateFee;

-- Lãi suất trung bình áp dụng cho một loại khoản vay.
CREATE OR ALTER FUNCTION fn_avg_interest_rate_by_loan_type
(
    @loan_type NVARCHAR(50)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
DECLARE @avg_rate DECIMAL(5,2);
SELECT @avg_rate = ISNULL(AVG(interest_rate), 0)
FROM bank_loan_accounts
WHERE loan_type = @loan_type;
RETURN @avg_rate;
END;
GO
-- CHECK
SELECT dbo.fn_avg_interest_rate_by_loan_type ('mortgage') AS avg_int_by_type 


# # NHÓM 2 - TRẢ NỢ & HÀNH VI KH

--Số ngày trễ hạn trung bình của khách hàng.
CREATE OR ALTER FUNCTION dbo.fn_avg_days_late_customer ( @customer_id INT )
RETURNS DECIMAL(10,2)
AS
BEGIN
DECLARE @avg_days DECIMAL(10,2);
WITH LateRepayments AS (
SELECT DATEDIFF(DAY, s.due_date, r.repayment_date) AS days_late
FROM bank_repayments r
INNER JOIN bank_loan_accounts l ON r.loan_id = l.loan_id
INNER JOIN bank_loan_schedule s ON r.loan_id = s.loan_id AND r.repayment_date >= s.due_date
WHERE l.customer_id = @customer_id
      AND r.is_late = 1
)
SELECT @avg_days = ISNULL(AVG(CAST(days_late AS DECIMAL(10,2))), 0)
FROM LateRepayments;
RETURN @avg_days;
END;
GO
-- CHECK:
SELECT fn_avg_days_late_customer(619) AS avg_late_day_by_cust

