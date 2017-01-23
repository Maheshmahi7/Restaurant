DROP FUNCTION IF EXISTS FN_GET_MENU_ID;
DELIMITER #
CREATE FUNCTION FN_GET_MENU_ID(item VARCHAR(50)) RETURNS INT
BEGIN
DECLARE X INT;
SET X=(SELECT menu.`id` FROM menu JOIN stock_remaining ON menu.`id`=stock_remaining.`menu_id` JOIN food_schedule ON food_schedule.`id`=stock_remaining.`schedule_id` WHERE menu.name=item AND CURRENT_TIME() BETWEEN from_time AND to_time);
RETURN X;
END; #
DELIMITER ;

DROP FUNCTION IF EXISTS FN_GET_SESSION_ID;
DELIMITER #
CREATE FUNCTION FN_GET_SESSION_ID(item VARCHAR(50)) RETURNS INT
BEGIN
RETURN (SELECT stock_remaining.`schedule_id` FROM stock_remaining JOIN food_schedule ON food_schedule.`id`=stock_remaining.`schedule_id` WHERE stock_remaining.`menu_id`=(SELECT FN_GET_MENU_ID(item)) AND CURRENT_TIME() BETWEEN from_time AND to_time);
END #
DELIMITER ;


DROP FUNCTION IF EXISTS FN_CHECK_ITEM_AVAILABILITY;
DELIMITER #
CREATE FUNCTION FN_CHECK_ITEM_AVAILABILITY(item VARCHAR(50),quantity INT) RETURNS VARCHAR(50)
BEGIN

DECLARE item_remaining INT;/*for validating current stock*/
DECLARE session_id INT;

SET session_id=(SELECT FN_GET_SESSION_ID(item));
/*to check session id is available or not*/
IF (session_id<>0)
THEN
	/*based on retrived session id and food name the food id will be retrived*/
	IF EXISTS (SELECT FN_GET_MENU_ID(item))
	THEN
		SET item_remaining=(SELECT stock_remaining.`quantity` FROM stock_remaining WHERE menu_id=(SELECT FN_GET_MENU_ID(item)) AND stock_remaining.`schedule_id`=session_id);
		/*checking the ordered quantity is less then remaining quantity*/
		IF (item_remaining>=quantity)
		THEN
			RETURN 'item available';
		ELSE
			RETURN 'item not available';
		END IF;
	ELSE 
		RETURN 'not served';
	END IF;
ELSE
	RETURN 'out of service';
END IF;				
END; #
DELIMITER ;


DROP FUNCTION IF EXISTS FN_CHECK_ORDER_LIST;
DELIMITER #
CREATE FUNCTION FN_CHECK_ORDER_LIST(items MEDIUMTEXT,quantitys MEDIUMTEXT)RETURNS INT
BEGIN
DECLARE COUNT INT;
DECLARE	item VARCHAR(50);/*for getting particular item from item list*/
DECLARE quantity INT;/*for getting quantity from quantity list*/
DECLARE i INT;/*looping variable*/
SET COUNT=0;
SET i=1;
	/*loop for ordering each item in the item list*/
	WHILE i<=(SELECT limits FROM order_limit)
	DO
		/*getting single item from item list*/
		SET item=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(items,',',i), ',',-1));
		/*getting single quantity from quantity list*/
		SET quantity=(SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(quantitys,',', i), ',',-1));
		/*checking if there is null in the item if not then procedure will be called*/
		IF (item<>'null')
		THEN
			SET COUNT=COUNT+1;
		END IF;
		SET i=i+1;
	END WHILE;
RETURN COUNT;
END; #
DELIMITER ;


DROP FUNCTION IF EXISTS FN_CHECK_SEAT_AVAILABILITY;
DELIMITER #
CREATE FUNCTION FN_CHECK_SEAT_AVAILABILITY(seat_no INT) RETURNS BOOLEAN
BEGIN
RETURN EXISTS (SELECT seat_id FROM seat_status WHERE seat_id=seat_no AND STATUS='AVAILABLE');
END #
DELIMITER ;


