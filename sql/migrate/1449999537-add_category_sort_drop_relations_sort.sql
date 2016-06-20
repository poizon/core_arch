-- 1449999537-add_category_sort_drop_relations_sort.sql created at Вс. 13 дек. 2015 12:38:57 (+0300)

ALTER TABLE store_category_relations DROP COLUMN sort;
ALTER TABLE store_category ADD COLUMN sort int(11) NOT NULL;
