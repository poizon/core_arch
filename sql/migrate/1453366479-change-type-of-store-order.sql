-- 1453366479-change-type-of-store-order.sql created at Thu Jan 21 14:54:39 2016 (+0600)

ALTER TABLE `store_order` ADD COLUMN `status_tmp` ENUM('NEW', 'PENDING', 'DONE', 'FAIL') NOT NULL DEFAULT 'NEW';
UPDATE `store_order` SET `status_tmp` = 'PENDING' WHERE `status` = 2;
UPDATE `store_order` SET `status_tmp` = 'DONE' WHERE `status` = 3;
UPDATE `store_order` SET `status_tmp` = 'FAIL' WHERE `status` = 4;
ALTER TABLE `store_order` DROP COLUMN `status`;
ALTER TABLE `store_order` CHANGE `status_tmp` `status` ENUM('NEW', 'PENDING', 'DONE', 'FAIL') NOT NULL DEFAULT 'NEW';