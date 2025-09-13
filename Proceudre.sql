-- Procedure usp_CloseLoanIfFullyPaid: 
--kiểm tra khoản vay đã trả đủ gốc+lãi → update loan_accounts.status = 'closed'.
CREATE OR ALTER PROCEDURE usp_CloseLoanIfFullyPaid
    @loan_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @principal DECIMAL(18,2);
    DECLARE @interest_rate DECIMAL(5,2);
    DECLARE @start_date DATE;
    DECLARE @due_date DATE;
    DECLARE @total_due DECIMAL(18,2);
    DECLARE @total_paid DECIMAL(18,2);
    DECLARE @last_payment_date DATE;
-- loan info
    SELECT 
        @principal = loan_amount,
        @interest_rate = interest_rate,
        @start_date = start_date,
        @due_date = due_date
    FROM bank_loan_accounts
    WHERE loan_id = @loan_id;
-- loan amount
    SET @total_due = @principal + 
                     (@principal * @interest_rate / 100.0 * DATEDIFF(DAY, @start_date, @due_date) / 365.0);
-- paid
    SELECT	@total_paid = ISNULL(SUM(repayment_amount), 0),
			@last_payment_date = MAX(repayment_date)
    FROM bank_repayments
    WHERE loan_id = @loan_id;
-- check runoff
    IF @total_paid >= @total_due
    BEGIN
        IF @last_payment_date < @due_date
            UPDATE loan_accounts
            SET status = 'prepaid'
            WHERE loan_id = @loan_id;
        ELSE
            UPDATE loan_accounts
            SET status = 'closed'
            WHERE loan_id = @loan_id;
        PRINT 'Loan ' + CAST(@loan_id AS NVARCHAR) + ' has been fully paid and status updated.';
    END
    ELSE
    BEGIN
        PRINT 'Loan ' + CAST(@loan_id AS NVARCHAR) + ' has not been fully paid yet.';
    END
END;
GO
-- Check
EXEC usp_CloseLoanIfFullyPaid @loan_id = 3;
SELECT loan_id, status FROM bank_loan_accounts WHERE loan_id = 3;



