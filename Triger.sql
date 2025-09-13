--  trigger để tự động cập nhật loan_accounts.status = 'overdue' khi có bản ghi trong repayments trả chậm quá 30 ngày.
CREATE OR ALTER TRIGGER trg_update_loan_status_overdue
ON bank_repayments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE a
    SET a.status = 'overdue'
    FROM bank_loan_accounts a
    INNER JOIN inserted b ON a.loan_id = b.loan_id
    INNER JOIN loan_schedule c ON c.loan_id = a.loan_id
    WHERE b.is_late = 1
      AND DATEDIFF(DAY, c.due_date, b.repayment_date) > 30
      AND a.status <> 'overdue';
END;
GO

-- Tạo trigger audit: mỗi khi update loan_accounts.status, ghi log vào bảng loan_status_history.
CREATE TABLE bank_loan_status_history (
    history_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_id INT NOT NULL,
    old_status NVARCHAR(20),
    new_status NVARCHAR(20),
    changed_at DATETIME DEFAULT GETDATE(),
    changed_by NVARCHAR(100) NULL 
	);
--
CREATE OR ALTER TRIGGER trg_audit_loan_status
ON bank_loan_accounts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO bank_loan_status_history (loan_id, old_status, new_status, changed_at)
    SELECT 
        d.loan_id,
        d.status AS old_status,
        i.status AS new_status,
        GETDATE()
    FROM deleted d
    INNER JOIN inserted i ON d.loan_id = i.loan_id
    WHERE d.status <> i.status; 
END;
GO
