-- =====================================================================
-- OPTIONAL sample requests for testing the dashboards and the calendar.
-- Run AFTER gso_database.sql. All names, numbers and IDs are made up.
-- Dates are relative to today so the calendar always looks populated.
-- ID photos are not included; upload files through the app to test those.
-- Assumes the starter accounts: admin = 1, secretary = 2, gso = 3,
-- and inventory ids: 1 chairs, 2 tables, 3 tents, 4 sound, 5 podium, 6 stage.
-- =====================================================================
USE gso_reservation;

-- 1  Approved (official), community event
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, address, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, status, reviewed_by, reviewed_at, approved_by, approved_at, created_at)
VALUES (@t, 'citizen', 'Maria Dela Cruz', '0917 555 0142', 'Inabanga, Bohol', 'Brgy. Poblacion Fiesta Committee',
  'Barangay fiesta night', 'comm', 'Poblacion plaza', CURDATE() + INTERVAL 7 DAY, CURDATE() + INTERVAL 8 DAY,
  'PhilSys National ID', '4021-5566-7788-1234', 'verified', 'approved', 3, NOW() - INTERVAL 6 HOUR, 2, NOW() - INTERVAL 5 HOUR, NOW() - INTERVAL 7 HOUR);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested, qty_recommended, qty_approved) VALUES
  (@r,1,200,200,200),(@r,3,3,3,3),(@r,2,20,20,20);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Maria Dela Cruz', 'Request submitted with ID and documents', NOW() - INTERVAL 7 HOUR),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID verified and stock checked. Forwarded to the Secretary', NOW() - INTERVAL 6 HOUR),
  (@r, 2, 'Private Secretary II', 'Approved. Reservation is official', NOW() - INTERVAL 5 HOUR);

-- 2  Waiting for the Secretary, competes with #1 for chairs (date conflict)
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, status, reviewed_by, reviewed_at, created_at)
VALUES (@t, 'lgu', 'Rafael Tumulak', '0928 555 0188', 'Municipal Health Office',
  'Community vaccination day', 'gov', 'Municipal gym', CURDATE() + INTERVAL 7 DAY, CURDATE() + INTERVAL 7 DAY,
  'LGU or agency employee ID', 'LGU-2021-0457', 'verified', 'for_approval', 3, NOW() - INTERVAL 3 HOUR, NOW() - INTERVAL 6 HOUR);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested, qty_recommended) VALUES (@r,1,150,150),(@r,2,15,15),(@r,4,1,1);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Rafael Tumulak', 'Request submitted with ID and documents', NOW() - INTERVAL 6 HOUR),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID verified and stock checked. Forwarded to the Secretary', NOW() - INTERVAL 3 HOUR);

-- 3  New, waiting for GSO review
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_expiry, id_status, status, created_at)
VALUES (@t, 'citizen', 'Jose Ramirez', '0935 555 0120', 'Debut celebration', 'priv',
  'Ramirez residence, Brgy. Bahi', CURDATE() + INTERVAL 7 DAY, CURDATE() + INTERVAL 7 DAY,
  'Driver''s License', 'N02-19-004411', CURDATE() + INTERVAL 400 DAY, 'pending', 'submitted', NOW() - INTERVAL 2 HOUR);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested) VALUES (@r,1,150),(@r,3,2),(@r,2,10);
INSERT INTO request_log (request_id, actor_label, message) VALUES (@r, 'Jose Ramirez', 'Request submitted with ID and documents');

-- 4  New, waiting for GSO review
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, status, created_at)
VALUES (@t, 'citizen', 'Ana Bacalso', '0917 555 0171', 'San Isidro Parish Youth', 'Youth retreat', 'comm',
  'Parish hall', CURDATE() + INTERVAL 12 DAY, CURDATE() + INTERVAL 13 DAY,
  'Voter''s ID or Voter''s Certificate', '7791-0023', 'pending', 'submitted', NOW() - INTERVAL 1 HOUR);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested) VALUES (@r,4,2),(@r,3,4),(@r,5,1);
INSERT INTO request_log (request_id, actor_label, message) VALUES (@r, 'Ana Bacalso', 'Request submitted with ID and documents');

-- 5  Released and still out (event running now)
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, status, reviewed_by, reviewed_at, approved_by, approved_at,
  released_by, released_at, received_by, original_id_checked, created_at)
VALUES (@t, 'lgu', 'Rafael Tumulak', '0928 555 0188', 'Inabanga National High School',
  'Foundation week program', 'comm', 'School grounds', CURDATE() - INTERVAL 1 DAY, CURDATE() + INTERVAL 1 DAY,
  'LGU or agency employee ID', 'DEPED-33812', 'verified', 'released', 3, NOW() - INTERVAL 3 DAY, 2, NOW() - INTERVAL 3 DAY,
  3, NOW() - INTERVAL 1 DAY, 'Rafael Tumulak', 1, NOW() - INTERVAL 4 DAY);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested, qty_recommended, qty_approved) VALUES (@r,2,30,30,30),(@r,1,100,100,100),(@r,6,1,1,1);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Rafael Tumulak', 'Request submitted with ID and documents', NOW() - INTERVAL 4 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID verified and stock checked. Forwarded to the Secretary', NOW() - INTERVAL 3 DAY),
  (@r, 2, 'Private Secretary II', 'Approved. Reservation is official', NOW() - INTERVAL 3 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'Items released to Rafael Tumulak; original ID checked', NOW() - INTERVAL 1 DAY);

-- 6  Returned (complete)
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_expiry, id_status, status, reviewed_by, reviewed_at, approved_by, approved_at,
  released_by, released_at, received_by, original_id_checked, returned_to, returned_at, return_condition, return_remarks, created_at)
VALUES (@t, 'business', 'Elena Villanueva', '0919 555 0166', 'Villanueva Catering', 'Wedding reception', 'priv',
  'Brgy. Tambook', CURDATE() - INTERVAL 6 DAY, CURDATE() - INTERVAL 5 DAY,
  'Passport', 'P1234567A', CURDATE() + INTERVAL 900 DAY, 'verified', 'returned', 3, NOW() - INTERVAL 9 DAY, 2, NOW() - INTERVAL 9 DAY,
  3, NOW() - INTERVAL 6 DAY, 'Elena Villanueva', 1, 3, NOW() - INTERVAL 4 DAY, 'ok', 'All items returned complete.', NOW() - INTERVAL 10 DAY);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested, qty_recommended, qty_approved, qty_returned) VALUES
  (@r,1,120,120,120,120),(@r,2,12,12,12,12),(@r,3,2,2,2,2);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Elena Villanueva', 'Request submitted with ID and documents', NOW() - INTERVAL 10 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID verified and stock checked. Forwarded to the Secretary', NOW() - INTERVAL 9 DAY),
  (@r, 2, 'Private Secretary II', 'Approved. Reservation is official', NOW() - INTERVAL 9 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'Items released to Elena Villanueva; original ID checked', NOW() - INTERVAL 6 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'Items returned complete and in good condition', NOW() - INTERVAL 4 DAY);

-- 7  ID rejected: the borrower must upload a new photo
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, id_note, status, reviewed_by, reviewed_at, created_at)
VALUES (@t, 'citizen', 'Pedro Lumayag', '0906 555 0137', 'Family reunion', 'priv', 'Brgy. Napo',
  CURDATE() + INTERVAL 9 DAY, CURDATE() + INTERVAL 9 DAY, 'Postal ID', 'PRN-889031', 'rejected',
  'Photo is blurry or cut off. Retake the photo with all four corners visible.', 'id_issue', 3, NOW() - INTERVAL 1 HOUR, NOW() - INTERVAL 5 HOUR);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested) VALUES (@r,1,60),(@r,2,6);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Pedro Lumayag', 'Request submitted with ID and documents', NOW() - INTERVAL 5 HOUR),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID rejected: Photo is blurry or cut off', NOW() - INTERVAL 1 HOUR);

-- 8  Approved (official), government activity
SET @t = fn_next_tracking();
INSERT INTO requests (tracking_no, requester_type, borrower_name, mobile, organization, event_name, event_category, venue,
  date_needed, date_return, id_type, id_number, id_status, status, reviewed_by, reviewed_at, approved_by, approved_at, created_at)
VALUES (@t, 'lgu', 'Dina Cabahug', '0927 555 0109', 'Municipal Sports Office', 'Municipal sports fest', 'gov',
  'Municipal oval', CURDATE() + INTERVAL 3 DAY, CURDATE() + INTERVAL 4 DAY,
  'LGU or agency employee ID', 'LGU-2019-0233', 'verified', 'approved', 3, NOW() - INTERVAL 1 DAY, 2, NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 2 DAY);
SET @r = LAST_INSERT_ID();
INSERT INTO request_items (request_id, item_id, qty_requested, qty_recommended, qty_approved) VALUES
  (@r,1,100,100,100),(@r,2,10,10,10),(@r,6,1,1,1),(@r,4,1,1,1);
INSERT INTO request_log (request_id, actor_user_id, actor_label, message, created_at) VALUES
  (@r, NULL, 'Dina Cabahug', 'Request submitted with ID and documents', NOW() - INTERVAL 2 DAY),
  (@r, 3, 'GSO Staff (Cultural in-charge)', 'ID verified and stock checked. Forwarded to the Secretary', NOW() - INTERVAL 1 DAY),
  (@r, 2, 'Private Secretary II', 'Approved. Reservation is official', NOW() - INTERVAL 1 DAY);

-- Quick check: should list 8 requests and show stock left for today
SELECT tracking_no, borrower_name, event_name, status, items_text FROM v_request_summary ORDER BY request_id;
SELECT * FROM v_stock_today;
