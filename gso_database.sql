-- =====================================================================
-- GSO Logistics Reservation & Tracking System
-- Office of the Municipal Mayor, General Services Office, Inabanga, Bohol
-- Database schema + reference data + staff accounts
-- Target: MariaDB 10.4+ / MySQL 5.7+ (XAMPP default). Import with phpMyAdmin
-- (Import tab) or:  mysql -u root < gso_database.sql
-- If creating the functions fails with error 1418 (binary logging is on), run
--   SET GLOBAL log_bin_trust_function_creators = 1;
-- and import again. XAMPP does not normally need this.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS gso_reservation
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE gso_reservation;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS audit_log, request_log, request_attachments, request_items, requests,
  inventory_items, required_documents, accepted_ids, requester_types, event_categories,
  settings, tracking_counters, users;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- Staff accounts. Public requesters do NOT have accounts.
-- password_hash holds a PHP password_hash() / bcrypt value, never plain text.
-- ---------------------------------------------------------------------
CREATE TABLE users (
  user_id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  full_name      VARCHAR(120) NOT NULL,
  username       VARCHAR(40)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  role           ENUM('admin','secretary','gso') NOT NULL,
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_users_username (username)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- System settings (editable by Admin)
-- ---------------------------------------------------------------------
CREATE TABLE settings (
  setting_key    VARCHAR(40)  NOT NULL,
  setting_value  VARCHAR(255) NOT NULL,
  description    VARCHAR(255) NULL,
  PRIMARY KEY (setting_key)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Event categories. Higher weight wins when two requests want the same
-- items on the same dates; ties go to whoever asked first (created_at).
-- ---------------------------------------------------------------------
CREATE TABLE event_categories (
  category_code    CHAR(4)      NOT NULL,
  label            VARCHAR(80)  NOT NULL,
  priority_weight  TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (category_code)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ID verification rules (Admin reviews and edits these)
-- ---------------------------------------------------------------------
CREATE TABLE requester_types (
  type_code    VARCHAR(10)  NOT NULL,
  label        VARCHAR(80)  NOT NULL,
  description  VARCHAR(255) NOT NULL,
  PRIMARY KEY (type_code)
) ENGINE=InnoDB;

CREATE TABLE accepted_ids (
  accepted_id_pk  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  type_code       VARCHAR(10)  NOT NULL,
  id_name         VARCHAR(120) NOT NULL,
  sort_order      SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (accepted_id_pk),
  UNIQUE KEY uq_accepted (type_code, id_name),
  CONSTRAINT fk_accepted_type FOREIGN KEY (type_code) REFERENCES requester_types (type_code)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Extra documents on top of the letter of request (which is always required)
CREATE TABLE required_documents (
  doc_pk       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  type_code    VARCHAR(10)  NOT NULL,
  doc_name     VARCHAR(160) NOT NULL,
  sort_order   SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (doc_pk),
  UNIQUE KEY uq_docs (type_code, doc_name),
  CONSTRAINT fk_docs_type FOREIGN KEY (type_code) REFERENCES requester_types (type_code)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Inventory (GSO and Admin edit the stock counts)
-- ---------------------------------------------------------------------
CREATE TABLE inventory_items (
  item_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
  item_name    VARCHAR(80)  NOT NULL,
  unit         VARCHAR(20)  NOT NULL DEFAULT 'pcs',
  total_stock  INT UNSIGNED NOT NULL DEFAULT 0,
  is_active    TINYINT(1)   NOT NULL DEFAULT 1,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (item_id),
  UNIQUE KEY uq_item_name (item_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Tracking number counter: GSO-<year>-<4 digits>, restarts every year
-- ---------------------------------------------------------------------
CREATE TABLE tracking_counters (
  yr        SMALLINT UNSIGNED NOT NULL,
  last_no   INT UNSIGNED      NOT NULL DEFAULT 0,
  PRIMARY KEY (yr)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Reservation requests (the digital Borrower's Slip)
--
-- status flow:
--   submitted     public sent the request; waiting for GSO review
--   id_issue      GSO rejected the ID; borrower must upload a new photo
--   for_approval  GSO verified ID and stock; waiting for the Secretary
--   approved      Secretary approved. The reservation is OFFICIAL
--   released      GSO handed the items over
--   returned      items are back; stock is free again
--   rejected      denied by the Secretary
--   cancelled     cancelled by the borrower
-- ---------------------------------------------------------------------
CREATE TABLE requests (
  request_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tracking_no      VARCHAR(20)  NOT NULL,
  requester_type   VARCHAR(10)  NOT NULL,
  borrower_name    VARCHAR(120) NOT NULL,
  mobile           VARCHAR(30)  NOT NULL,
  mobile_last4     CHAR(4) AS (RIGHT(REPLACE(REPLACE(REPLACE(REPLACE(mobile,' ',''),'-',''),'+',''),'(',''),4)) STORED,
  address          VARCHAR(200) NULL,
  organization     VARCHAR(160) NULL,
  event_name       VARCHAR(160) NOT NULL,
  event_category   CHAR(4)      NOT NULL DEFAULT 'priv',
  venue            VARCHAR(200) NOT NULL,
  date_needed      DATE         NOT NULL,
  date_return      DATE         NOT NULL,

  -- ID verification
  id_type          VARCHAR(120) NOT NULL,
  id_number        VARCHAR(60)  NOT NULL,
  id_expiry        DATE         NULL,
  id_status        ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
  id_note          VARCHAR(255) NULL,

  status           ENUM('submitted','id_issue','for_approval','approved','released','returned','rejected','cancelled')
                   NOT NULL DEFAULT 'submitted',

  -- GSO review (step 1)
  reviewed_by      INT UNSIGNED NULL,
  reviewed_at      DATETIME     NULL,
  -- Secretary final approval (step 2)
  approved_by      INT UNSIGNED NULL,
  approved_at      DATETIME     NULL,
  remarks          VARCHAR(255) NULL,
  -- Release (step 3)
  released_by      INT UNSIGNED NULL,
  released_at      DATETIME     NULL,
  received_by      VARCHAR(120) NULL,
  received_by_rep  TINYINT(1)   NOT NULL DEFAULT 0,
  original_id_checked TINYINT(1) NOT NULL DEFAULT 0,
  -- Return (step 4)
  returned_to      INT UNSIGNED NULL,
  returned_at      DATETIME     NULL,
  return_condition ENUM('ok','damaged','missing') NULL,
  return_remarks   VARCHAR(255) NULL,

  consent_given    TINYINT(1)   NOT NULL DEFAULT 1,
  created_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (request_id),
  UNIQUE KEY uq_requests_tracking (tracking_no),
  KEY ix_requests_status (status),
  KEY ix_requests_dates (date_needed, date_return),
  KEY ix_requests_borrower (borrower_name),
  CONSTRAINT ck_requests_dates CHECK (date_return >= date_needed),
  CONSTRAINT fk_requests_type  FOREIGN KEY (requester_type) REFERENCES requester_types (type_code),
  CONSTRAINT fk_requests_cat   FOREIGN KEY (event_category) REFERENCES event_categories (category_code),
  CONSTRAINT fk_requests_rev   FOREIGN KEY (reviewed_by) REFERENCES users (user_id),
  CONSTRAINT fk_requests_apr   FOREIGN KEY (approved_by) REFERENCES users (user_id),
  CONSTRAINT fk_requests_rel   FOREIGN KEY (released_by) REFERENCES users (user_id),
  CONSTRAINT fk_requests_ret   FOREIGN KEY (returned_to) REFERENCES users (user_id)
) ENGINE=InnoDB;

-- Items on a request. Quantities at each stage:
--   qty_requested   what the borrower asked for
--   qty_recommended what GSO recommends after checking stock
--   qty_approved    what the Secretary approved (this is what blocks stock)
--   qty_returned    what came back
CREATE TABLE request_items (
  request_id       INT UNSIGNED NOT NULL,
  item_id          INT UNSIGNED NOT NULL,
  qty_requested    INT UNSIGNED NOT NULL,
  qty_recommended  INT UNSIGNED NULL,
  qty_approved     INT UNSIGNED NULL,
  qty_returned     INT UNSIGNED NULL,
  PRIMARY KEY (request_id, item_id),
  KEY ix_request_items_item (item_id),
  CONSTRAINT ck_items_qty CHECK (qty_requested > 0),
  CONSTRAINT fk_items_request FOREIGN KEY (request_id) REFERENCES requests (request_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_items_item FOREIGN KEY (item_id) REFERENCES inventory_items (item_id)
) ENGINE=InnoDB;

-- Uploaded ID photos and documents. Store the FILE on disk (outside the
-- public web folder if possible) and only the path here.
-- slot: front, back, selfie, letter, doc0, doc1, ...
CREATE TABLE request_attachments (
  attachment_id  INT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     INT UNSIGNED NOT NULL,
  slot           VARCHAR(20)  NOT NULL,
  file_path      VARCHAR(255) NOT NULL,
  original_name  VARCHAR(160) NULL,
  mime_type      VARCHAR(60)  NOT NULL,
  uploaded_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (attachment_id),
  UNIQUE KEY uq_attachment_slot (request_id, slot),
  CONSTRAINT fk_att_request FOREIGN KEY (request_id) REFERENCES requests (request_id)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- Timeline shown on the public Track page and in the staff request view
CREATE TABLE request_log (
  log_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     INT UNSIGNED NOT NULL,
  actor_user_id  INT UNSIGNED NULL,           -- NULL = the borrower
  actor_label    VARCHAR(120) NOT NULL,
  message        VARCHAR(255) NOT NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (log_id),
  KEY ix_log_request (request_id, created_at),
  CONSTRAINT fk_log_request FOREIGN KEY (request_id) REFERENCES requests (request_id)
    ON DELETE CASCADE,
  CONSTRAINT fk_log_user FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- System-wide audit trail (sign-ins, stock edits, rule changes, ...)
CREATE TABLE audit_log (
  audit_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        INT UNSIGNED NULL,
  actor_label    VARCHAR(120) NOT NULL,
  action         VARCHAR(255) NOT NULL,
  tracking_no    VARCHAR(20)  NULL,
  ip_address     VARCHAR(45)  NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (audit_id),
  KEY ix_audit_time (created_at),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users (user_id)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- =====================================================================
-- Reference data
-- =====================================================================
INSERT INTO settings (setting_key, setting_value, description) VALUES
  ('advance_days',   '5', 'Days of advance notice requested from borrowers'),
  ('require_selfie', '0', '1 = borrower must upload a selfie holding the ID');

INSERT INTO event_categories (category_code, label, priority_weight) VALUES
  ('gov',  'Government / official activity',          3),
  ('comm', 'Community, school, church or barangay',   2),
  ('priv', 'Private or business event',               1);

INSERT INTO requester_types (type_code, label, description) VALUES
  ('citizen',  'Citizen (G2C)',                          'Individuals, families and residents borrowing for a personal or community event.'),
  ('lgu',      'Government office or LGU staff (G2G)',   'Employees borrowing for an official activity of a government office.'),
  ('business', 'Business, organization or group',        'Owners or representatives of businesses, schools, churches and associations.');

INSERT INTO accepted_ids (type_code, id_name, sort_order) VALUES
  ('citizen','PhilSys National ID',1),('citizen','Driver''s License',2),('citizen','Passport',3),
  ('citizen','UMID',4),('citizen','Voter''s ID or Voter''s Certificate',5),('citizen','Postal ID',6),
  ('citizen','PRC ID',7),('citizen','Senior Citizen ID',8),('citizen','PWD ID',9),
  ('citizen','Barangay ID or Certificate of Residency',10),
  ('lgu','LGU or agency employee ID',1),('lgu','Any government-issued ID listed for citizens',2),
  ('business','Driver''s License',1),('business','Passport',2),('business','PhilSys National ID',3),
  ('business','UMID',4),('business','Voter''s ID or Voter''s Certificate',5),
  ('business','Company or organization ID with a government ID',6);

INSERT INTO required_documents (type_code, doc_name, sort_order) VALUES
  ('lgu','Endorsement or memo signed by the office head',1),
  ('business','Authorization letter from the owner or organization',1),
  ('business','Business permit or organization registration',2);

INSERT INTO inventory_items (item_id, item_name, unit, total_stock) VALUES
  (1,'Plastic chairs','pcs',400),
  (2,'Tables','pcs',60),
  (3,'Tents','units',10),
  (4,'Sound system','sets',3),
  (5,'Podium','pcs',4),
  (6,'Stage platform','sets',2);

-- Starter staff accounts (bcrypt hashes). CHANGE THESE PASSWORDS after first sign-in.
--   admin     / admin123
--   secretary / sec123
--   gso       / gso123
INSERT INTO users (full_name, username, password_hash, role) VALUES
  ('Municipal Mayor''s Office',      'admin',     '$2y$10$yMWocbC2CCWjO//BMYA3qeIKZ73pkKx7frY/dmKBH9ptVygICHTxC', 'admin'),
  ('Private Secretary II',           'secretary', '$2y$10$HekgVlKuru9btTuYHdTY5OGowOwqjGO0jIlYU7tTrc4wF3zwrnemC', 'secretary'),
  ('GSO Staff (Cultural in-charge)', 'gso',       '$2y$10$KCZG2/WfdOUl5TKy55r5g.8e5rgDzsCquvJXzta1621US1vWIqn86', 'gso');

-- =====================================================================
-- Functions
-- =====================================================================
DELIMITER $$

-- Next tracking number, e.g. GSO-2026-0001. Call it BEFORE the insert:
--   SET @t = fn_next_tracking();
--   INSERT INTO requests (tracking_no, ...) VALUES (@t, ...);
CREATE FUNCTION fn_next_tracking() RETURNS VARCHAR(20)
  NOT DETERMINISTIC MODIFIES SQL DATA
BEGIN
  DECLARE v_year SMALLINT UNSIGNED;
  SET v_year = YEAR(CURDATE());
  INSERT INTO tracking_counters (yr, last_no) VALUES (v_year, LAST_INSERT_ID(1))
    ON DUPLICATE KEY UPDATE last_no = LAST_INSERT_ID(last_no + 1);
  RETURN CONCAT('GSO-', v_year, '-', LPAD(LAST_INSERT_ID(), 4, '0'));
END$$

-- Units of an item that are already OFFICIALLY reserved (approved or
-- released) on any day between p_start and p_end. p_exclude = a request_id
-- to ignore (use 0 to ignore nothing).
CREATE FUNCTION fn_committed(p_item INT UNSIGNED, p_start DATE, p_end DATE, p_exclude INT UNSIGNED)
  RETURNS INT
  NOT DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE v_total INT;
  SELECT COALESCE(SUM(COALESCE(ri.qty_approved, ri.qty_requested)), 0) INTO v_total
    FROM request_items ri
    JOIN requests r ON r.request_id = ri.request_id
   WHERE ri.item_id = p_item
     AND r.request_id <> p_exclude
     AND r.status IN ('approved','released')
     AND r.date_needed <= p_end
     AND r.date_return >= p_start;
  RETURN v_total;
END$$

-- Units still free for those dates
CREATE FUNCTION fn_available(p_item INT UNSIGNED, p_start DATE, p_end DATE, p_exclude INT UNSIGNED)
  RETURNS INT
  NOT DETERMINISTIC READS SQL DATA
BEGIN
  DECLARE v_stock INT;
  SELECT total_stock INTO v_stock FROM inventory_items WHERE item_id = p_item;
  RETURN GREATEST(0, COALESCE(v_stock, 0) - fn_committed(p_item, p_start, p_end, p_exclude));
END$$

-- =====================================================================
-- Workflow procedures. Each one checks the caller's role and the current
-- status, changes the request, and writes the timeline entry. Errors are
-- raised with SQLSTATE 45000 so the PHP code can show the message.
-- =====================================================================

-- STEP 1 (GSO or Admin): ID verified and stock checked. Forward to Secretary.
-- Recommended quantity = what was asked, limited to what is available.
CREATE PROCEDURE sp_gso_forward(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED)
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20);
  DECLARE v_start DATE; DECLARE v_end DATE; DECLARE v_name VARCHAR(120);

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('gso','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only GSO or Admin can review requests';
  END IF;

  SELECT request_id, status, date_needed, date_return INTO v_id, v_status, v_start, v_end
    FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'submitted' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is not waiting for GSO review';
  END IF;

  UPDATE request_items
     SET qty_recommended = LEAST(qty_requested, fn_available(item_id, v_start, v_end, v_id))
   WHERE request_id = v_id;
  IF (SELECT COALESCE(SUM(qty_recommended),0) FROM request_items WHERE request_id = v_id) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No stock is available for these dates';
  END IF;

  UPDATE requests
     SET status = 'for_approval', id_status = 'verified', id_note = NULL,
         reviewed_by = p_user, reviewed_at = NOW()
   WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name, 'ID verified and stock checked. Forwarded to the Secretary');
  INSERT INTO audit_log (user_id, actor_label, action, tracking_no)
    VALUES (p_user, v_name, 'Forwarded request to the Secretary', p_tracking);
END$$

-- STEP 1 alternative (GSO or Admin): reject the ID. The borrower uploads a
-- new photo from the Track page and the status returns to 'submitted'.
CREATE PROCEDURE sp_gso_reject_id(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED, IN p_reason VARCHAR(255))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20); DECLARE v_name VARCHAR(120);

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('gso','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only GSO or Admin can review requests';
  END IF;

  SELECT request_id, status INTO v_id, v_status FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'submitted' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is not waiting for GSO review';
  END IF;

  UPDATE requests SET status = 'id_issue', id_status = 'rejected', id_note = p_reason,
         reviewed_by = p_user, reviewed_at = NOW() WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name, CONCAT('ID rejected: ', p_reason));
END$$

-- Borrower uploaded a new ID photo (call after saving the new files).
-- Caller must first check the last 4 digits of the mobile number.
CREATE PROCEDURE sp_borrower_resubmit(IN p_tracking VARCHAR(20), IN p_mobile_last4 CHAR(4), IN p_id_number VARCHAR(60))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_name VARCHAR(120);
  SELECT request_id, borrower_name INTO v_id, v_name FROM requests
   WHERE tracking_no = p_tracking AND mobile_last4 = p_mobile_last4 AND status = 'id_issue' FOR UPDATE;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request not found or the mobile digits do not match';
  END IF;
  UPDATE requests SET status = 'submitted', id_status = 'pending', id_note = NULL, id_number = p_id_number
   WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, NULL, v_name, 'New ID photo uploaded by the borrower');
END$$

-- Borrower cancels (needs the last 4 digits of the mobile number)
CREATE PROCEDURE sp_borrower_cancel(IN p_tracking VARCHAR(20), IN p_mobile_last4 CHAR(4))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_name VARCHAR(120);
  SELECT request_id, borrower_name INTO v_id, v_name FROM requests
   WHERE tracking_no = p_tracking AND mobile_last4 = p_mobile_last4
     AND status IN ('submitted','id_issue','for_approval','approved') FOR UPDATE;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request not found, already processed, or the mobile digits do not match';
  END IF;
  UPDATE requests SET status = 'cancelled' WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, NULL, v_name, 'Request cancelled by the borrower');
END$$

-- STEP 2 (Secretary or Admin): FINAL approval. The reservation becomes
-- official and the approved quantities start blocking stock.
-- Approved quantity = GSO recommendation, limited to what is still available.
-- To approve fewer units, UPDATE request_items.qty_recommended first.
CREATE PROCEDURE sp_secretary_approve(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED, IN p_remarks VARCHAR(255))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20);
  DECLARE v_start DATE; DECLARE v_end DATE; DECLARE v_name VARCHAR(120);

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('secretary','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the Secretary or Admin can approve';
  END IF;

  SELECT request_id, status, date_needed, date_return INTO v_id, v_status, v_start, v_end
    FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'for_approval' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is not waiting for final approval';
  END IF;

  UPDATE request_items
     SET qty_approved = LEAST(COALESCE(qty_recommended, qty_requested), fn_available(item_id, v_start, v_end, v_id))
   WHERE request_id = v_id;
  IF (SELECT COALESCE(SUM(qty_approved),0) FROM request_items WHERE request_id = v_id) = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No stock is available. Deny the request instead';
  END IF;

  UPDATE requests SET status = 'approved', approved_by = p_user, approved_at = NOW(), remarks = p_remarks
   WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name, 'Approved. Reservation is official');
  INSERT INTO audit_log (user_id, actor_label, action, tracking_no)
    VALUES (p_user, v_name, 'Approved reservation', p_tracking);
END$$

-- STEP 2 alternative (Secretary or Admin): deny
CREATE PROCEDURE sp_secretary_deny(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED, IN p_reason VARCHAR(255))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20); DECLARE v_name VARCHAR(120);

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('secretary','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only the Secretary or Admin can deny';
  END IF;

  SELECT request_id, status INTO v_id, v_status FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'for_approval' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is not waiting for final approval';
  END IF;

  UPDATE requests SET status = 'rejected', remarks = p_reason WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name, CONCAT('Request denied: ', p_reason));
END$$

-- STEP 3 (GSO or Admin): release the items after checking the ORIGINAL ID
CREATE PROCEDURE sp_gso_release(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED,
                                IN p_received_by VARCHAR(120), IN p_is_representative TINYINT,
                                IN p_original_id_checked TINYINT)
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20); DECLARE v_name VARCHAR(120);

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('gso','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only GSO or Admin can release items';
  END IF;
  IF p_original_id_checked <> 1 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Check the borrower''s original ID before releasing';
  END IF;

  SELECT request_id, status INTO v_id, v_status FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'approved' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request is not approved for release';
  END IF;

  UPDATE requests
     SET status = 'released', released_by = p_user, released_at = NOW(), received_by = p_received_by,
         received_by_rep = p_is_representative, original_id_checked = 1
   WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name,
            CONCAT('Items released to ', p_received_by,
                   IF(p_is_representative = 1, ' (representative)', ''), '; original ID checked'));
END$$

-- STEP 4 (GSO or Admin): APPROVE the return. This closes the request and frees the stock.
-- To record partial returns, first UPDATE request_items.qty_returned per item;
-- items with qty_returned still NULL are counted as fully returned.
CREATE PROCEDURE sp_gso_return(IN p_tracking VARCHAR(20), IN p_user INT UNSIGNED,
                               IN p_condition VARCHAR(10), IN p_remarks VARCHAR(255))
BEGIN
  DECLARE v_id INT UNSIGNED; DECLARE v_status VARCHAR(20); DECLARE v_name VARCHAR(120);
  DECLARE v_short INT;

  SELECT full_name INTO v_name FROM users
   WHERE user_id = p_user AND is_active = 1 AND role IN ('gso','admin');
  IF v_name IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only GSO or Admin can record returns';
  END IF;

  SELECT request_id, status INTO v_id, v_status FROM requests WHERE tracking_no = p_tracking FOR UPDATE;
  IF v_id IS NULL OR v_status <> 'released' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request has no items out';
  END IF;

  UPDATE request_items SET qty_returned = qty_approved WHERE request_id = v_id AND qty_returned IS NULL;
  SELECT COUNT(*) INTO v_short FROM request_items
   WHERE request_id = v_id AND COALESCE(qty_approved,0) > 0 AND qty_returned < qty_approved;
  IF (v_short > 0 OR p_condition <> 'ok') AND (p_remarks IS NULL OR p_remarks = '') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Add remarks about the missing or damaged items';
  END IF;

  UPDATE requests
     SET status = 'returned', returned_to = p_user, returned_at = NOW(),
         return_condition = p_condition, return_remarks = p_remarks
   WHERE request_id = v_id;
  INSERT INTO request_log (request_id, actor_user_id, actor_label, message)
    VALUES (v_id, p_user, v_name,
            IF(v_short = 0 AND p_condition = 'ok',
               'Return approved by GSO: items complete and in good condition',
               CONCAT('Return approved by GSO with issues: ', p_remarks)));
END$$

DELIMITER ;

-- =====================================================================
-- Views used by the dashboards
-- =====================================================================

-- Calendar: every request that holds or may hold dates (staff calendars).
-- The PUBLIC page only needs status IN ('approved','released').
CREATE OR REPLACE VIEW v_calendar_events AS
SELECT r.request_id, r.tracking_no, r.event_name, r.borrower_name, r.organization,
       r.date_needed, r.date_return, r.status, r.event_category
  FROM requests r
 WHERE r.status IN ('submitted','for_approval','approved','released');

-- One line of items per request, e.g. "200 Plastic chairs, 3 Tents"
CREATE OR REPLACE VIEW v_request_summary AS
SELECT r.request_id, r.tracking_no, r.borrower_name, r.organization, r.requester_type,
       r.event_name, r.event_category, r.venue, r.date_needed, r.date_return, r.status,
       r.id_status, r.created_at,
       (SELECT GROUP_CONCAT(CONCAT(COALESCE(ri.qty_approved, ri.qty_requested), ' ', i.item_name)
                            ORDER BY i.item_name SEPARATOR ', ')
          FROM request_items ri JOIN inventory_items i ON i.item_id = ri.item_id
         WHERE ri.request_id = r.request_id) AS items_text
  FROM requests r;

-- Items still out after their return date
CREATE OR REPLACE VIEW v_overdue_returns AS
SELECT r.tracking_no, r.borrower_name, r.mobile, r.event_name, r.date_return,
       DATEDIFF(CURDATE(), r.date_return) AS days_overdue
  FROM requests r
 WHERE r.status = 'released' AND r.date_return < CURDATE();

-- Stock today (inventory screen)
CREATE OR REPLACE VIEW v_stock_today AS
SELECT i.item_id, i.item_name, i.unit, i.total_stock,
       fn_committed(i.item_id, CURDATE(), CURDATE(), 0) AS committed_today,
       fn_available(i.item_id, CURDATE(), CURDATE(), 0) AS available_today
  FROM inventory_items i
 WHERE i.is_active = 1;

-- Work queues, one per role
CREATE OR REPLACE VIEW v_queue_gso_review AS
  SELECT * FROM v_request_summary WHERE status = 'submitted' ORDER BY created_at;
CREATE OR REPLACE VIEW v_queue_secretary AS
  SELECT * FROM v_request_summary WHERE status = 'for_approval' ORDER BY created_at;
CREATE OR REPLACE VIEW v_queue_gso_release AS
  SELECT * FROM v_request_summary WHERE status = 'approved' ORDER BY date_needed;

-- =====================================================================
-- Handy queries for the PHP code (copy into your prepared statements)
-- =====================================================================
-- 1) Submit a request (inside one transaction):
--      SET @t = fn_next_tracking();
--      INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, ...)
--      VALUES (@t, ?, ?, ?, ...);
--      SET @rid = LAST_INSERT_ID();
--      INSERT INTO request_items (request_id, item_id, qty_requested) VALUES (@rid, ?, ?), ...;
--      INSERT INTO request_attachments (request_id, slot, file_path, mime_type) VALUES (@rid, 'front', ?, ?), ...;
--      INSERT INTO request_log (request_id, actor_label, message)
--        VALUES (@rid, ?, 'Request submitted with ID and documents');
--      SELECT @t AS tracking_no;   -- show this to the borrower
--
-- 2) Public Track page (tracking number only, no personal data returned):
--      SELECT tracking_no, event_name, date_needed, date_return, status, items_text
--        FROM v_request_summary WHERE tracking_no = ?;
--      SELECT message, created_at FROM request_log
--       WHERE request_id = (SELECT request_id FROM requests WHERE tracking_no = ?)
--       ORDER BY created_at;
--
-- 3) Stock for a date range (public Reserve form and staff screens):
--      SELECT item_id, item_name, total_stock,
--             fn_available(item_id, ?, ?, 0) AS available
--        FROM inventory_items WHERE is_active = 1;
--
-- 4) Calendar day (staff): requests on one date
--      SELECT * FROM v_calendar_events WHERE ? BETWEEN date_needed AND date_return;
--    Public calendar day: same query with  AND status IN ('approved','released').
--
-- 5) Date conflicts: pending requests that want more than GSO owns
--      SELECT a.tracking_no, i.item_name,
--             a.qty_requested + COALESCE(SUM(o.qty), 0) AS demand, i.total_stock
--        FROM (SELECT r.request_id, r.tracking_no, r.date_needed, r.date_return, ri.item_id, ri.qty_requested
--                FROM requests r JOIN request_items ri USING (request_id)
--               WHERE r.status IN ('submitted','for_approval')) a
--        JOIN inventory_items i ON i.item_id = a.item_id
--        LEFT JOIN (SELECT r2.request_id, r2.date_needed, r2.date_return, ri2.item_id,
--                          COALESCE(ri2.qty_approved, ri2.qty_requested) AS qty
--                     FROM requests r2 JOIN request_items ri2 USING (request_id)
--                    WHERE r2.status IN ('submitted','for_approval','approved','released')) o
--               ON o.item_id = a.item_id AND o.request_id <> a.request_id
--              AND o.date_needed <= a.date_return AND o.date_return >= a.date_needed
--       GROUP BY a.request_id, a.tracking_no, i.item_name, a.qty_requested, i.total_stock
--      HAVING demand > i.total_stock;
--    Priority between two conflicting requests:
--      ORDER BY (SELECT priority_weight FROM event_categories WHERE category_code = r.event_category) DESC,
--               r.created_at ASC;
--
-- 6) Staff sign-in:  SELECT user_id, full_name, role, password_hash
--                      FROM users WHERE username = ? AND is_active = 1;
--    then verify with PHP:  password_verify($input, $row['password_hash']).
--
-- 7) Workflow calls:
--      CALL sp_gso_forward('GSO-2026-0001', <gso_user_id>);
--      CALL sp_gso_reject_id('GSO-2026-0001', <gso_user_id>, 'Photo is blurry or cut off');
--      CALL sp_secretary_approve('GSO-2026-0001', <secretary_user_id>, NULL);
--      CALL sp_secretary_deny('GSO-2026-0001', <secretary_user_id>, 'Items not available for the dates');
--      CALL sp_gso_release('GSO-2026-0001', <gso_user_id>, 'Juan Dela Cruz', 0, 1);
--      CALL sp_gso_return('GSO-2026-0001', <gso_user_id>, 'ok', NULL);
--      CALL sp_borrower_resubmit('GSO-2026-0001', '9876', 'NEW-ID-NUMBER');
--      CALL sp_borrower_cancel('GSO-2026-0001', '9876');
