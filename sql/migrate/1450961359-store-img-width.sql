-- 1450961359-store-img-width.sql created at четверг, 24 декабря 2015 г. 15:49:19 (+0300)

ALTER TABLE `sites` 
	ADD `store_imgsize_product`  SMALLINT UNSIGNED NULL AFTER `store_freedelivery`, 
	ADD `store_imgsize_category` SMALLINT UNSIGNED NULL AFTER `store_imgsize_product`;