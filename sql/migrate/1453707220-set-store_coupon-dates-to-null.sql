-- 1453707220-set-store_coupon-dates-to-null.sql created at Mon Jan 25 13:33:40 2016 (+0600)

ALTER TABLE `store_coupon` MODIFY `date_start` DATE NULL DEFAULT NULL;
ALTER TABLE `store_coupon` MODIFY `date_end` DATE NULL DEFAULT NULL;