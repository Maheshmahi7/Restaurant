CREATE TABLE food_schedule (
id INT NOT NULL,
SCHEDULE VARCHAR(50) NOT NULL,
from_time TIME NOT NULL,
to_time TIME NOT NULL,
quantity INT NOT NULL,
PRIMARY KEY (`id`),
UNIQUE KEY `UNIQUE` (`schedule`)
)


CREATE TABLE menu (                                                                                                                                                                                                                                                                                                               
id INT NOT NULL,
NAME VARCHAR(50) NOT NULL,
price INT DEFAULT NULL,
PRIMARY KEY (`id`),
)



CREATE TABLE seat (
id INT NOT NULL,
NAME VARCHAR(50) DEFAULT NULL,
PRIMARY KEY (`id`)
)


CREATE TABLE seat_status (
id INT NOT NULL AUTO_INCREMENT,
seat_id INT NOT NULL,
STATUS VARCHAR(50) NOT NULL,
PRIMARY KEY ('id'), 
CONSTRAINT seat_no FOREIGN KEY (`seat_id`) REFERENCES seat(`id`)
)



CREATE TABLE order_limit (
id INT NOT NULL AUTO_INCREMENT,
limits INT DEFAULT NULL,
PRIMARY KEY (`id`)
)


CREATE TABLE orders (
id INT NOT NULL AUTO_INCREMENT,
seat_id INT NOT NULL,
PRIMARY KEY (`id`),
CONSTRAINT ORDER_SEAT_NO FOREIGN KEY (`seat_id`) REFERENCES seat(`id`)
)


CREATE TABLE transaction_hotel (
id INT NOT NULL AUTO_INCREMENT,
order_id INT DEFAULT NULL,
menu_id INT NOT NULL,
quantity INT DEFAULT NULL,
ordered_time TIME DEFAULT NULL,
STATUS VARCHAR(200) DEFAULT NULL,
PRIMARY KEY (`id`),
CONSTRAINT item FOREIGN KEY (`menu_id`) REFERENCES menu(`id`),
CONSTRAINT order_id FOREIGN KEY (`order_id`) REFERENCES orders(`id`),
)



CREATE TABLE bill (
id INT NOT NULL AUTO_INCREMENT,
order_id INT(11) DEFAULT NULL,
no_of_items_order INT DEFAULT '0',
total_cost INT DEFAULT '0',
STATUS VARCHAR(50) DEFAULT NULL,
PRIMARY KEY (`id`),
CONSTRAINT BILL_ORDER_ID FOREIGN KEY (`order_id`) REFERENCES orders(`id`),
)



CREATE TABLE stock_remaining (
id INT NOT NULL AUTO_INCREMENT,
menu_id INT NOT NULL,
schedule_id INT NOT NULL,
quantity INT NOT NULL DEFAULT '0',
PRIMARY KEY (`id`),
CONSTRAINT food FOREIGN KEY (`menu_id`) REFERENCES menu(`id`),
CONSTRAINT TYPE FOREIGN KEY (`schedule_id`) REFERENCES food_schedule(`id`)
)



DELIMITER #
CREATE TRIGGER TR_ON_SEAT_INSERT
AFTER INSERT ON seat
FOR EACH ROW
BEGIN
INSERT INTO seat_status(seat_id,STATUS)VALUES(new.id,'available');
END #
DELIMITER ;




INSERT INTO food_schedule(id,SCHEDULE,from_time,to_time,quantity) VALUES(1,'Breakfast','08:00:00','11:00:00',100),(2,'Lunch','11:15:00','15:00:00',75),(3,'Refreshment','15:15:00','23:00:00',200),(4,'Dinner','19:00:00','23:00:00',100);


INSERT INTO menu(id,NAME,food_schedule,price) VALUES (1,'Idly',6),(2,'Vada',6),(3,'Dosa',10),(4,'Poori',10),(5,'Pongal',25),(6,'Coffee',10),(7,'Tea',8),(8,'South Indian Meals',55),(9,'North Indian Thali',65),
(10,'Variety Rice',30),(11,'Snacks',10),(12,'Fried rice',50),(13,'Chapatti',10),(14,'Chat Items',25);


INSERT INTO stock_remaning(menu_id,schedule_id,quantity) values(1,1,100),(2,1,100),(3,1,100),(4,1,100),(5,1,100),(6,1,100),(7,1,100),(8,2,75),(9,2,75),
(10,2,75),(6,3,200),(7,3,200),(11,3,200),(12,4,100),(13,4,100),(14,4,100);


INSERT INTO seat(id,NAME) VALUES(1,Seat1),(2,Seat2),(3,Seat3),(4,Seat4),(5,Seat5),(6,Seat6),(7,Seat7),(8,Seat8),(9,Seat9),(10,Seat10);


INSERT INTO seat_status(seat_id,STATUS) VALUES (1,'available'),(2,'available'),(3,'available'),(4,'available'),(5,'available'),(6,'available'),(7,'available'),(8,'available'),(9,'available'),(10,'available');



INSERT INTO order_limit(limits) VALUES(5);


