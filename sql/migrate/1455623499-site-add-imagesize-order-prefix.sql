ALTER TABLE `okis`.`sites` 
ADD COLUMN `store_order_suffix` VARCHAR(32) NULL DEFAULT NULL AFTER `favicon`,
ADD COLUMN `store_order_prefix` VARCHAR(32) NULL DEFAULT NULL AFTER `store_order_suffix`;
