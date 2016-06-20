-- 1453652611-coupons.sql created at воскресенье, 24 января 2016 г. 19:23:31 (+0300)

ALTER TABLE `store_coupon` CHANGE `date_start` `date_start` DATE NULL DEFAULT NULL, CHANGE `date_end` `date_end` DATE NULL DEFAULT NULL;