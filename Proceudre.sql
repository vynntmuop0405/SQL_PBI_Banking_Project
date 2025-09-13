-- Procedure usp_CloseLoanIfFullyPaid: 
--kiểm tra khoản vay đã trả đủ gốc+lãi → update loan_accounts.status = 'closed'.
CREATE OR ALTER PROCEDURE usp_CloseLoanIfFullyPaid
    @loan_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @total_due DECIMAL(18,2);
    DECLARE @total_paid DECIMAL(18,2);
    DECLARE @current_status NVARCHAR(20);
    -- Tổng phải trả
    SELECT @total_due = ISNULL(SUM(expected_amount),0)
    FROM bank_loan_schedule
    WHERE loan_id = @loan_id;
    -- Tổng đã trả
    SELECT @total_paid = ISNULL(SUM(repayment_amount),0)
    FROM bank_repayments
    WHERE loan_id = @loan_id;
    -- Status hiện tại (đang set open hết)
    SELECT @current_status = status
    FROM bank_loan_accounts
    WHERE loan_id = @loan_id;
    PRINT 'Loan ID: ' + CAST(@loan_id AS NVARCHAR);
    PRINT 'Total Due: ' + CAST(@total_due AS NVARCHAR);
    PRINT 'Total Paid: ' + CAST(@total_paid AS NVARCHAR);
    PRINT 'Current Status: ' + ISNULL(@current_status,'NULL');
    -- Trả đủ
    IF (@total_paid >= @total_due AND @current_status NOT IN ('closed','prepaid'))
    BEGIN
        UPDATE loan_accounts
        SET status = 'closed'
        WHERE loan_id = @loan_id;
        PRINT 'Loan is fully paid → status updated to CLOSED';
    END
    ELSE IF (@current_status IN ('closed','prepaid'))
    BEGIN
        PRINT 'Loan already CLOSED or PREPAID';
    END
    ELSE
    BEGIN
        PRINT 'Loan NOT fully paid yet';
    END
END;
GO
-- CHECK
EXEC usp_CloseLoanIfFullyPaid @loan_id = 1;

--- Procedure usp_ApplyPrepaymentPenalty: 
--- khi khách hàng tất toán trước hạn → tính phí phạt (2% dư nợ gốc) và insert vào penalties.
CREATE OR ALTER PROCEDURE usp_ApplyPrepaymentPenalty
    @loan_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @loan_amount DECIMAL(18,2);
    DECLARE @total_paid DECIMAL(18,2);
    DECLARE @due_date DATE;
    DECLARE @status NVARCHAR(20);
    DECLARE @penalty_amount DECIMAL(18,2);
    -- Lấy thông tin khoản vay
    SELECT 
        @loan_amount = loan_amount,
        @due_date = due_date,
        @status = status
    FROM bank_loan_accounts
    WHERE loan_id = @loan_id;
    -- Tổng đã trả
    SELECT @total_paid = ISNULL(SUM(repayment_amount),0)
    FROM bank_repayments
    WHERE loan_id = @loan_id;
    PRINT 'Loan ID: ' + CAST(@loan_id AS NVARCHAR);
    PRINT 'Loan Amount: ' + CAST(@loan_amount AS NVARCHAR);
    PRINT 'Total Paid: ' + CAST(@total_paid AS NVARCHAR);
    PRINT 'Status: ' + ISNULL(@status,'NULL');
    -- Chỉ áp dụng nếu là PREPAID
    IF (@status = 'prepaid')
    BEGIN
        DECLARE @remaining_principal DECIMAL(18,2);
        SET @remaining_principal = @loan_amount - @total_paid;

        -- Nếu khách hàng tất toán trước hạn
        IF (@remaining_principal > 0 AND GETDATE() < @due_date)
        BEGIN
            SET @penalty_amount = ROUND(@remaining_principal * 0.02, 2);
            INSERT INTO penalties (loan_id, penalty_amount, penalty_type, applied_date)
            VALUES (@loan_id, @penalty_amount, 'prepayment_fee', GETDATE());
            PRINT 'Prepayment penalty applied: ' + CAST(@penalty_amount AS NVARCHAR);
        END
        ELSE
        BEGIN
            PRINT 'No prepayment penalty (either fully paid or not before due date)';
        END
    END
    ELSE
    BEGIN
        PRINT 'Loan is not PREPAID → penalty not applied';
    END
END;
GO
-- CHECK
EXEC usp_ApplyPrepaymentPenalty @loan_id = 49


