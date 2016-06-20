-- 1453360134-change-type-of-store-coupon.sql created at Thu Jan 21 13:08:54 2016 (+0600)

ALTER TABLE `store_coupon` ADD COLUMN `type_tmp` ENUM('REL', 'ABS') NOT NULL;
UPDATE `store_coupon` SET `type_tmp` = IF(`type` = 1, 'REL', 'ABS');
ALTER TABLE `store_coupon` DROP COLUMN `type`;
ALTER TABLE `store_coupon` CHANGE `type_tmp` `type` ENUM('REL', 'ABS');