-- 1452847587-gallery-albums-per-page.sql created at пятница, 15 января 2016 г. 11:46:27 (+0300)

ALTER TABLE `gallery_albums` ADD `per_page` TINYINT UNSIGNED NULL DEFAULT NULL COMMENT 'Images per page' ;
