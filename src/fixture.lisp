(in-package #:cl-stack-llm-demo)

(defun decode-args (args)
  (cond
    ((hash-table-p args) args)
    ((and (stringp args) (plusp (length (string-trim '(#\Space #\Tab #\Newline) args))))
     (stack-json:decode args))
    (t (mcp-protocol:json-object))))

(defun %arg (obj key &optional default)
  (or (mcp-protocol:param obj key)
      (mcp-protocol:param obj (string-downcase (string key)))
      default))

(defparameter *orders*
  (alexandria:alist-hash-table
   `(("1001" . ,(mcp-protocol:json-object
                 "order_id" "1001"
                 "customer" "Sam Lee"
                 "item" "Ergo keyboard"
                 "status" "in_transit"
                 "promised" "yesterday"
                 "new_eta" "this Friday"
                 "note" "carrier delay at the regional hub — we already filed a tracer"))
     ("1002" . ,(mcp-protocol:json-object
                 "order_id" "1002"
                 "customer" "Riley Chen"
                 "item" "USB-C hub"
                 "status" "delivered"
                 "delivered" "2026-08-10"
                 "refund_eligible" t
                 "note" "30-day window still open; refund to original card in 5 business days"))
     ("1003" . ,(mcp-protocol:json-object
                 "order_id" "1003"
                 "customer" "Jordan Patel"
                 "item" "Desk mat"
                 "status" "processing"
                 "new_eta" "Tuesday"
                 "note" "warehouse pick not started")))
   :test 'equal))

(defparameter *kb*
  (alexandria:alist-hash-table
   `(("password-reset" . ,(mcp-protocol:json-object
                           "topic" "password-reset"
                           "steps" "Open account.northwind.example/reset, enter the account email, use the 30-minute link. We never ask for the current password."
                           "note" "If the mailbox is locked, the customer must contact billing first."))
     ("returns" . ,(mcp-protocol:json-object
                    "topic" "returns"
                    "steps" "30-day return from delivery. Unopened or defective. Label from the order page."
                    "note" "Refund posts to the original payment in 5 business days.")))
   :test 'equal))

(defun lookup-order (order-id)
  (let* ((id (string-trim '(#\Space #\Tab) (princ-to-string (or order-id ""))))
         (row (gethash id *orders*)))
    (or row (mcp-protocol:json-object "error" "unknown order" "order_id" id))))

(defun lookup-kb (topic)
  (let* ((key (string-downcase (string-trim '(#\Space #\Tab) (princ-to-string (or topic "")))))
         (row (or (gethash key *kb*)
                  (loop for k being the hash-keys of *kb*
                        when (search key k) return (gethash k *kb*)))))
    (or row (mcp-protocol:json-object "error" "no article" "topic" key))))

(defparameter *desk-instructions*
  "You are the Northwind Gear support desk.

Rules:
- Never invent order facts, dates, refunds, or tracking.
- If the customer mentions an order id, call lookup_order first.
- For how-to questions (password, returns), call lookup_kb.
- After you have verified facts, call draft_reply with customer, issue, and the JSON facts.
- Then send the customer the draft. One short paragraph of your own is fine.")

(defparameter *usecases*
  (list
   (list :id "late-shipment"
         :title "Late keyboard"
         :user "Hi — order 1001 was supposed to land yesterday and nothing showed up. What's going on? — Sam"
         :tools '("lookup_order" "draft_reply"))
   (list :id "refund"
         :title "USB-C hub refund"
         :user "Order 1002 arrived but the hub is the wrong SKU. Can I get a refund? — Riley"
         :tools '("lookup_order" "draft_reply"))
   (list :id "password-reset"
         :title "Locked out"
         :user "I can't sign in and I forgot the password. Walk me through reset? — Jordan"
         :tools '("lookup_kb" "draft_reply"))))
