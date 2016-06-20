-- 1446758324-store_item_param_value_price_null.sql created at пятница,  6 ноября 2015 г. 00:18:44 (+0300)

ALTER TABLE `store_item_param_value` CHANGE `price` `price` DECIMAL(10,2) NULL DEFAULT NULL;