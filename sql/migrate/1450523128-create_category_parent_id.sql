-- 1450523128-create_category_parent_id.sql created at Сб. 19 дек. 2015 14:05:28 (+0300)

ALTER TABLE `store_category` 
    ADD `parent_id` INT UNSIGNED NOT NULL AFTER `site_id`;
ALTER TABLE store_category
    ADD INDEX parent_idx (`parent_id`);

