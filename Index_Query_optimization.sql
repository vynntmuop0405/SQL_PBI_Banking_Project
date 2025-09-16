-- BẢNG BANK_LOAN_ACCOUNTS:
Có loan_id là primary key -> auto là clustered index
Tạo thêm NONCLUSTERED INDEX để tìm theo khách hàng, thống kê trạng thái hoặc nợ đến hạn.

CREATE NONCLUSTERED INDEX ind_loan_accounts_customer
ON bank_loan_accounts(customer_id)

CREATE NONCLUSTERED INDEX ind_loan_accounts_status
ON bank_loan_accounts(status)

CREATE NONCLUSTERED INDEX ind_loan_accounts_due_date 
    ON bank_loan_accounts(due_date)

-- BẢNG BANK_REPAYMENTS:
Tạo thêm NONCLUSTERED INDEX để tìm theo loan_id, ngày trả nợ, theo kì trả nợ

CREATE NONCLUSTERED INDEX ind_repayments_loan 
    ON bank_repayments(loan_id);

CREATE NONCLUSTERED INDEX ind_repayments_due_payment 
    ON bank_repayments(payment_date);

CREATE NONCLUSTERED INDEX ind_repayments_installment 
    ON bank_repayments(installment_no);

-- BẢNG BANK_TRANSACTIONS
Tạo thêm NONCLUSTERED INDEX để tìm theo mã khoản vay, tối ưu phân tích theo thời gian, thống kê giao dịch

CREATE NONCLUSTERED INDEX ind_transactions_loan 
    ON bank_transactions(loan_id);

CREATE NONCLUSTERED INDEX ind_transactions_date 
    ON bank_transactions(transaction_date)

CREATE NONCLUSTERED INDEX ind_transactions_type 
    ON bank_transactions(transaction_type)