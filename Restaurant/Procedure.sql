DELIMITER #
CREATE PROCEDURE PR_TAKE_ORDER(IN i_seat_no INT,IN i_items MEDIUMTEXT,IN i_quantitys MEDIUMTEXT)
BEGIN
DECLARE	item VARCHAR(50);/*for getting particular item from item list*/
DECLARE quantity INT;/*for getting quantity from quantity list*/
DECLARE i INT;/*looping variable*/

	/*checking the given seat is available or not*/
	IF FN_CHECK_SEAT_AVAILABILITY(i_seat_no)
	THEN
		SET i=1;
		INSERT INTO orders(seat_id) VALUES(i_seat_no);
		UPDATE seat_status
		SET STATUS='taken'
		WHERE seat_id=i_seat_no;
		/*loop for ordering each item in the item list*/
		WHILE i<=(SELECT FN_CHECK_ORDER_LIST(i_items,i_quantitys))
		DO
			/*getting single item from item list*/
			SET item=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(i_items,',',i), ',',-1));
			/*getting single quantity from quantity list*/
			SET quantity=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(i_quantitys,',', i), ',',-1));
			/*checking if there is null in the item if not then procedure will be called*/
			CALL PR_ORDER_ITEM(i_seat_no,item,quantity);
			
			SET i=i+1;
		END WHILE;
		
	ELSE
	SELECT 'Sorry selected seat is currently not available' AS message;
	END IF;
END #
DELIMITER ;

CALL PR_TAKE_ORDER(1,'Coffee,Tea,Idly,null,null','1,1,2,0,0');


DELIMITER #
CREATE PROCEDURE PR_ORDER_ITEM(IN i_seat_no INT,IN i_item VARCHAR(50),IN i_quantity INT)
BEGIN
DECLARE condition_statement INT;/*used to get output from function condition*/

/*session id is retrived*/
SET condition_statement=(SELECT FN_CONDITIONS(i_item,i_quantity));/*calling conditions function*/

/*Based on function output the case below will executed*/
CASE condition_statement
	WHEN 1 THEN
		START TRANSACTION;
		SET autocommit=0;
		/*it will update food remaining and set seat status as taken and insert it into transaction table*/
		UPDATE stock_remaining
		SET quantity=quantity-i_quantity
		WHERE menu_id=(SELECT FN_GET_MENU_ID(i_item));
		CALL PR_UPDATE_BILL((SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1),(i_quantity*(SELECT price FROM menu WHERE id=(SELECT FN_GET_MENU_ID(i_item)))),1);
		
		INSERT INTO transaction_hotel(order_id,menu_id,quantity,ordered_time,STATUS) VALUES ((SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1),(SELECT FN_GET_MENU_ID(i_item)),i_quantity,CURRENT_TIME(),'Delivered');
		COMMIT;
	WHEN 2 THEN
		SELECT CONCAT(i_item,' is currently not available. Please order something else') AS message;
	WHEN 3 THEN
		SELECT 'This item will not be served at the moment' AS message;
	WHEN 4 THEN
		SELECT 'Sorry we are out of service at the moment' AS message;
END CASE;
END #
DELIMITER ;



DELIMITER #
CREATE PROCEDURE PR_CANCEL_ORDER(IN i_seat_no INT,IN i_item VARCHAR(50))
BEGIN
DECLARE item_id INT;/*For getting food id*/
DECLARE transaction_id INT;/*For retriving transaction id*/
DECLARE order_no INT;

SET item_id=(SELECT FN_GET_MENU_ID(i_item));
SET order_no=(SELECT id FROM orders WHERE seat_id=i_seat_no ORDER BY id DESC LIMIT 1);
SET transaction_id=(SELECT id FROM transaction_hotel WHERE order_id=order_no AND menu_id=item_id);

/*To check whether the given item and seat no exists in the transaction and if not display soory message*/
IF EXISTS (SELECT id FROM bill WHERE seat_id=i_seat_no AND order_id=order_no AND STATUS='Pending')
THEN
	
	START TRANSACTION;
	SET autocommit=0;
	/*update statement for updating cancelled order in food remaining table*/
	UPDATE stock_remaining
	SET quantity=quantity+(SELECT quantity FROM transaction_hotel WHERE id=transaction_id)
	WHERE menu_id=item_id;
	/*delete that record from the transaction table*/
	UPDATE transaction_hotel
	SET STATUS='Cancelled'
	WHERE id=transaction_id;
	
	UPDATE bill
	SET no_of_items_order=no_of_items_order-1,
	total_cost=total_cost-(SELECT price FROM menu WHERE id=item_id)
	WHERE order_id=order_no;
	IF NOT EXISTS (SELECT order_id FROM transaction_hotel WHERE order_id=order_no AND transaction_hotel.`status`='Delivered')
	THEN
		UPDATE seat_status
		SET seat_status.`status`='available'
		WHERE seat_id=i_seat_no;
		UPDATE bill
		SET bill.`status`='Cancelled'
		WHERE order_id=order_no;
	END IF;
	COMMIT;
ELSE
SELECT 'Sorry enter the correct item you ordered or seat no' AS message;
END IF;
END #
DELIMITER ;

CALL PR_CANCEL_ORDER(10,'South Indian Meals')


DELIMITER #
CREATE PROCEDURE PR_UPDATE_BILL(IN i_order_id INT,IN i_cost INT,IN i_total_count INT)
BEGIN
IF NOT EXISTS(SELECT id FROM bill WHERE order_id=i_order_id)
THEN
INSERT INTO bill(order_id,no_of_items_order,total_cost,STATUS) VALUES (i_order_id,i_total_count,i_cost,'Pending');
ELSE
UPDATE bill
SET no_of_items_order=no_of_items_order+i_total_count,
total_cost=total_cost+i_cost
WHERE order_id=i_order_id;
END IF;
END #
DELIMITER ;



DELIMITER # 
CREATE PROCEDURE PR_PAY_BILL(IN i_order_id INT)
BEGIN
IF EXISTS(SELECT id FROM bill WHERE order_id=i_order_id AND STATUS='Pending')
THEN
UPDATE bill
SET STATUS='Paid'
WHERE order_id=i_order_id;
UPDATE seat_status
SET STATUS='available'
WHERE seat_id=(SELECT seat_id FROM orders WHERE id=i_order_id);
SELECT 'Bill Paid' AS Message;
ELSE
SELECT 'Bill already paid' AS Message;
END IF;
END #
DELIMITER ;

CALL PR_PAY_BILL(10)


CREATE VIEW VR_STOCK_REMAINING AS SELECT menu.`id`'S.no',menu.`name`'Items',(SELECT food_schedule.`schedule` FROM food_schedule WHERE food_schedule.`id`=menu.`food_schedule`)'Schedule',stock_remaining.`quantity` 
FROM menu JOIN stock_remaining ON menu.`id`=stock_remaining.`menu_id`;

SELECT * FROM VR_STOCK_REMAINING


SET GLOBAL event_scheduler=ON;

DELIMITER #
CREATE EVENT EV_END_DAY_UPDATE 
ON SCHEDULE EVERY 1 DAY 
STARTS '2017-01-19 00:20:00' ON COMPLETION PRESERVE ENABLE
DO
BEGIN
	START TRANSACTION;
	SET autocommit=0;
	/*if true it will truncate transaction and set seat status as available and update the food quantity for next day*/
	TRUNCATE transaction_hotel;
	UPDATE seat_status
	SET STATUS='available';
	UPDATE stock_remaining 
	SET quantity=(SELECT quantity FROM food_schedule WHERE stock_remaining.`schedule_id`=food_schedule.`id`);
	COMMIT;
END #
DELIMITER ;