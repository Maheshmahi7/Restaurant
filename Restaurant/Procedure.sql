DELIMITER #
CREATE PROCEDURE PR_TAKE_ORDER(IN i_seat_no INT,IN i_items MEDIUMTEXT,IN i_quantitys MEDIUMTEXT,OUT message_status VARCHAR(200))
BEGIN
DECLARE	item VARCHAR(50);/*for getting particular item from item list*/
DECLARE quantity INT;/*for getting quantity from quantity list*/
DECLARE i INT;/*looping variable*/
DECLARE order_no INT;

	/*checking the given seat is available or not*/
	IF FN_CHECK_SEAT_AVAILABILITY(i_seat_no)
	THEN
		SET i=1;
		INSERT INTO orders(seat_id) VALUES(i_seat_no);
		UPDATE seat_status
		SET STATUS='TAKEN'
		WHERE seat_id=i_seat_no;
		SET order_no=(SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1);
		/*loop for ordering each item in the item list*/
		WHILE i<=(SELECT FN_CHECK_ORDER_LIST(i_items,i_quantitys))
		DO
			/*getting single item from item list*/
			SET item=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(i_items,',',i), ',',-1));
			/*getting single quantity from quantity list*/
			SET quantity=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(i_quantitys,',', i), ',',-1));
			/*checking if there is null in the item if not then procedure will be called*/
			CALL PR_ORDER_ITEM(i_seat_no,item,quantity,@message_order);
			SELECT @message_order INTO message_status;
			SET i=i+1;
		END WHILE;
		CALL PR_PAY_BILL(order_no,@message_pay);
	ELSE
	SET message_status='Sorry selected seat is currently not available';
	END IF;
END #
DELIMITER ;

CALL PR_TAKE_ORDER(1,'Coffee,Tea,Idly,null,null','1,1,2,0,0',@message);


DELIMITER #
CREATE PROCEDURE PR_ORDER_ITEM(IN i_seat_no INT,IN i_item VARCHAR(50),IN i_quantity INT,OUT message_order VARCHAR(200))
BEGIN
DECLARE condition_statement VARCHAR(50);/*used to get output from function condition*/
DECLARE order_no INT;
DECLARE cost INT;
DECLARE menu_no INT;
DECLARE session_id INT;

/*session id is retrived*/
SET condition_statement=(SELECT FN_CHECK_ITEM_AVAILABILITY(i_item,i_quantity));/*calling conditions function*/
SET order_no=(SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1);
SET cost=(i_quantity*(SELECT price FROM menu WHERE NAME=i_item));
SET menu_no=(SELECT FN_GET_MENU_ID(i_item));
SET session_id=(SELECT FN_GET_SESSION_ID(i_item));
/*Based on function output the case below will executed*/
CASE condition_statement
	WHEN 'item available' THEN
		START TRANSACTION;
		SET autocommit=0;
		/*it will update food remaining and set seat status as taken and insert it into transaction table*/
		UPDATE stock_remaining
		SET quantity=quantity-i_quantity
		WHERE menu_id=menu_no AND schedule_id=session_id;
		CALL PR_UPDATE_BILL(order_no,cost);
		
		INSERT INTO transaction_hotel(order_id,menu_id,quantity,ordered_time,STATUS) VALUES (order_no,menu_no,i_quantity,CURRENT_TIME(),'DELIVERED');
		SELECT CONCAT(i_item, ' Delivered') INTO message_order;
		COMMIT;
	WHEN 'item not available' THEN
		SELECT CONCAT(i_item,' is currently not available. Please order something else') INTO message_order;
	WHEN 'not served' THEN
		SELECT CONCAT(i_item,'This item will not be served at the moment') INTO message_order;
	WHEN 'out of service' THEN
		SELECT 'Sorry we are out of service at the moment' INTO message_order;
END CASE;
END #
DELIMITER ;



DELIMITER #
CREATE PROCEDURE PR_CANCEL_ORDER(IN i_seat_no INT,IN i_item VARCHAR(50),OUT message_cancel VARCHAR(200))
BEGIN
DECLARE item_id INT;/*For getting food id*/
DECLARE transaction_id INT;/*For retriving transaction id*/
DECLARE order_no INT;
DECLARE session_id INT;

SET item_id=(SELECT FN_GET_MENU_ID(i_item));
SET order_no=(SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1);
SET transaction_id=(SELECT id FROM transaction_hotel WHERE order_id=order_no AND menu_id=item_id);
SET session_id=(SELECT FN_GET_SESSION_ID(i_item));

/*To check whether the given item and seat no exists in the transaction and if not display soory message*/
IF EXISTS (SELECT id FROM bill WHERE order_id=order_no AND STATUS='PENDING')
THEN
	
	START TRANSACTION;
	SET autocommit=0;
	/*update statement for updating cancelled order in food remaining table*/
	UPDATE stock_remaining
	SET quantity=quantity+(SELECT quantity FROM transaction_hotel WHERE id=transaction_id)
	WHERE menu_id=item_id AND schedule_id=session_id;
	/*delete that record from the transaction table*/
	UPDATE transaction_hotel
	SET STATUS='CANCELLED'
	WHERE id=transaction_id;
	
	UPDATE bill
	SET total_cost=total_cost-(SELECT price FROM menu WHERE id=item_id)
	WHERE order_id=order_no;
	IF NOT EXISTS (SELECT order_id FROM transaction_hotel WHERE order_id=order_no AND transaction_hotel.`status`='DELIVERED')
	THEN
		UPDATE seat_status
		SET seat_status.`status`='AVAILABLE'
		WHERE seat_id=i_seat_no;
		UPDATE bill
		SET bill.`status`='CANCELLED'
		WHERE order_id=order_no;
	END IF;
	SELECT CONCAT(i_item,' Cancelled') INTO message_cancel;
	COMMIT;
ELSE
SELECT 'Sorry enter the correct item you ordered or seat no' INTO message_cancel;
END IF;
END #
DELIMITER ;

CALL PR_CANCEL_ORDER(10,'South Indian Meals')


DELIMITER #
CREATE PROCEDURE PR_UPDATE_BILL(IN i_order_id INT,IN i_cost INT)
BEGIN
IF NOT EXISTS(SELECT id FROM bill WHERE order_id=i_order_id)
THEN
INSERT INTO bill(order_id,total_cost,STATUS) VALUES (i_order_id,i_cost,'PENDING');
ELSE
UPDATE bill
SET total_cost=total_cost+i_cost
WHERE order_id=i_order_id;
END IF;
END #
DELIMITER ;



DELIMITER # 
CREATE PROCEDURE PR_PAY_BILL(IN i_order_id INT,OUT message_pay VARCHAR(200))
BEGIN
IF EXISTS(SELECT id FROM bill WHERE order_id=i_order_id AND STATUS='PENDING')
THEN
UPDATE bill
SET STATUS='PAID'
WHERE order_id=i_order_id;
UPDATE seat_status
SET STATUS='AVAILABLE'
WHERE seat_id=(SELECT seat_id FROM orders WHERE id=i_order_id);
SELECT 'Bill Paid' INTO message_pay;
ELSE
SELECT 'Bill already paid' INTO message_pay;
END IF;
END #
DELIMITER ;

CALL PR_PAY_BILL(10)


CREATE VIEW VR_STOCK_REMAINING AS SELECT menu.`id`'S.no',menu.`name`'Items',(SELECT food_schedule.`schedule` FROM food_schedule WHERE id=stock_remaining.`schedule_id`)'Schedule',stock_remaining.`quantity` 
FROM menu JOIN stock_remaining ON menu.`id`=stock_remaining.`menu_id`;

SELECT * FROM VR_STOCK_REMAINING


SET GLOBAL event_scheduler=ON;

DELIMITER #
CREATE EVENT EV_END_DAY_UPDATE 
ON SCHEDULE EVERY 1 DAY 
STARTS '2017-01-20 00:20:00' ON COMPLETION PRESERVE ENABLE
DO
BEGIN
	START TRANSACTION;
	SET autocommit=0;
	/*if true it will truncate transaction and set seat status as available and update the food quantity for next day*/
	TRUNCATE transaction_hotel;
	UPDATE seat_status
	SET STATUS='AVAILABLE';
	UPDATE stock_remaining 
	SET quantity=(SELECT quantity FROM food_schedule WHERE stock_remaining.`schedule_id`=food_schedule.`id`);
	COMMIT;
END #
DELIMITER ;