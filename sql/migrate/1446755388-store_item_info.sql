-- 1446755388-store_item_info.sql created at четверг,  5 ноября 2015 г. 23:29:48 (+0300)

CREATE TABLE `store_item_info` (
`info_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `value` varchar(5000) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Additional characteristics for products';

--
-- Индексы таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
 ADD PRIMARY KEY (`info_id`), ADD KEY `item_id` (`item_id`);
 
 --
-- AUTO_INCREMENT для таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
MODIFY `info_id` int(11) unsigned NOT NULL AUTO_INCREMENT;

--
-- Ограничения внешнего ключа таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
ADD CONSTRAINT `store_item_info_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;
