-- phpMyAdmin SQL Dump
-- version 4.2.10
-- http://www.phpmyadmin.net
--
-- Хост: localhost:8889
-- Время создания: Дек 22 2015 г., 23:06
-- Версия сервера: 5.5.38
-- Версия PHP: 5.6.2

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

--
-- База данных: `okis`
--

-- --------------------------------------------------------

--
-- Структура таблицы `affiliate_sites`
--

CREATE TABLE `affiliate_sites` (
`site_id` int(10) unsigned NOT NULL,
  `affiliate_id` int(10) unsigned NOT NULL,
  `domain` varchar(255) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `lang` varchar(5) NOT NULL DEFAULT '',
  `theme` varchar(16) NOT NULL DEFAULT '',
  `css` varchar(8000) NOT NULL DEFAULT '',
  `footer` varchar(6000) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Sites for white label affiliate program';

-- --------------------------------------------------------

--
-- Структура таблицы `affiliate_stat`
--

CREATE TABLE `affiliate_stat` (
`stat_id` int(11) unsigned NOT NULL,
  `affiliate_id` int(11) unsigned NOT NULL,
  `sum` decimal(10,2) NOT NULL DEFAULT '0.00',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `title` varchar(1024) NOT NULL DEFAULT '',
  `payment_id` int(10) unsigned DEFAULT NULL COMMENT 'NULL if withdrawals'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Affiliate statistics';

-- --------------------------------------------------------

--
-- Структура таблицы `affiliate_users`
--

CREATE TABLE `affiliate_users` (
`affiliate_id` int(11) unsigned NOT NULL,
  `email` varchar(256) NOT NULL,
  `password` varchar(256) NOT NULL,
  `regdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lang` varchar(5) NOT NULL DEFAULT '',
  `tz` varchar(64) DEFAULT NULL COMMENT 'Timezone',
  `country` char(2) DEFAULT NULL COMMENT '2-letter ISO country code',
  `percent` tinyint(3) unsigned DEFAULT NULL COMMENT 'Percent for partner'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Affiliate users';

-- --------------------------------------------------------

--
-- Структура таблицы `blocks`
--

CREATE TABLE `blocks` (
`block_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `value` varchar(20000) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `blog_comments`
--

CREATE TABLE `blog_comments` (
`comment_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `post_id` int(11) unsigned NOT NULL,
  `date` datetime DEFAULT NULL,
  `name` varchar(512) NOT NULL DEFAULT '',
  `email` varchar(512) NOT NULL DEFAULT '',
  `body` varchar(8000) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Blog comments';

-- --------------------------------------------------------

--
-- Структура таблицы `blog_posts`
--

CREATE TABLE `blog_posts` (
`post_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(512) NOT NULL DEFAULT '',
  `date` datetime DEFAULT NULL,
  `body` varchar(20000) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Blog posts';

-- --------------------------------------------------------

--
-- Структура таблицы `domains`
--

CREATE TABLE `domains` (
`domain_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `ascii` varchar(255) NOT NULL,
  `unicode` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Domains';

-- --------------------------------------------------------

--
-- Структура таблицы `domains_queue`
--

CREATE TABLE `domains_queue` (
`id` int(10) unsigned NOT NULL,
  `action` smallint(1) unsigned NOT NULL DEFAULT '1' COMMENT '1-new,2-prolong',
  `did` int(10) unsigned NOT NULL COMMENT 'domains_reg.id',
  `src` text,
  `contacts` text,
  `result` text,
  `status` int(10) unsigned DEFAULT '1' COMMENT '1-new,2-ok,3-error',
  `dt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `payed` int(10) unsigned DEFAULT NULL COMMENT '1 if payed'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `domains_reg`
--

CREATE TABLE `domains_reg` (
`id` int(11) unsigned NOT NULL,
  `user_id` int(11) unsigned DEFAULT NULL,
  `domain` varchar(255) NOT NULL,
  `dt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` int(11) unsigned DEFAULT '1' COMMENT '1-new,2-payed,3-has data to register,4-error(but payed),5-registered,6-deleted,7-do_prolong,8-prolong_error',
  `domain_id` int(11) unsigned DEFAULT NULL,
  `site_id` int(11) unsigned DEFAULT NULL COMMENT 'planned site to connect',
  `reg_date` timestamp NULL DEFAULT NULL,
  `reg_till` timestamp NULL DEFAULT NULL,
  `action` tinyint(1) unsigned DEFAULT '1' COMMENT 'current action: 1-register,2-prolong,NULL=nothing to do',
  `service_id` int(11) DEFAULT NULL COMMENT 'used to renew with REGru'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='set status=6 instead of deleting rows!!!';

-- --------------------------------------------------------

--
-- Структура таблицы `events`
--

CREATE TABLE `events` (
`event_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(512) NOT NULL DEFAULT '',
  `date_start` datetime DEFAULT NULL,
  `date_end` datetime DEFAULT NULL,
  `location` varchar(512) NOT NULL DEFAULT '',
  `desc_short` varchar(4000) NOT NULL DEFAULT '',
  `desc_full` varchar(8000) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Events table';

-- --------------------------------------------------------

--
-- Структура таблицы `form_info`
--

CREATE TABLE `form_info` (
`form_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `name` text NOT NULL,
  `descr` text,
  `reply_email` varchar(255) NOT NULL DEFAULT '',
  `finish_message` text,
  `nocaptcha` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Forms';

-- --------------------------------------------------------

--
-- Структура таблицы `form_questions`
--

CREATE TABLE `form_questions` (
`form_question_id` int(11) unsigned NOT NULL,
  `form_id` int(11) unsigned NOT NULL,
  `type` enum('text','textarea','select','checkbox','radio','file') NOT NULL DEFAULT 'text',
  `question` text NOT NULL,
  `descr` text,
  `priority` int(11) NOT NULL DEFAULT '0',
  `is_required` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Form questions';

-- --------------------------------------------------------

--
-- Структура таблицы `form_question_options`
--

CREATE TABLE `form_question_options` (
`form_question_option_id` int(11) unsigned NOT NULL,
  `form_question_id` int(11) unsigned NOT NULL,
  `option` varchar(255) NOT NULL,
  `priority` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Question options';

-- --------------------------------------------------------

--
-- Структура таблицы `forum_posts`
--

CREATE TABLE `forum_posts` (
`post_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned DEFAULT NULL,
  `topic_id` int(10) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `body` text,
  `author` varchar(64) NOT NULL DEFAULT '',
  `rating` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `forum_topics`
--

CREATE TABLE `forum_topics` (
`topic_id` int(10) unsigned NOT NULL,
  `user_id` int(10) unsigned DEFAULT NULL,
  `lang` varchar(5) NOT NULL DEFAULT 'en',
  `category` varchar(32) NOT NULL DEFAULT '',
  `title` varchar(255) NOT NULL DEFAULT '',
  `body` text,
  `author` varchar(64) NOT NULL DEFAULT '',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `closed` tinyint(1) NOT NULL DEFAULT '0',
  `sticky` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `gallery_albums`
--

CREATE TABLE `gallery_albums` (
`album_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `cover_id` int(11) unsigned NOT NULL,
  `title` varchar(1024) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `size` smallint(5) unsigned DEFAULT NULL COMMENT 'Pictures size'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Gallery albums table';

-- --------------------------------------------------------

--
-- Структура таблицы `gallery_photos`
--

CREATE TABLE `gallery_photos` (
`photo_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `album_id` int(11) unsigned DEFAULT NULL,
  `filename` varchar(255) NOT NULL DEFAULT '',
  `title` varchar(1024) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `sort` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Gallery photos table';

-- --------------------------------------------------------

--
-- Структура таблицы `logs`
--

CREATE TABLE `logs` (
`id` int(11) unsigned NOT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `ip` varchar(32) NOT NULL DEFAULT '',
  `ua` varchar(512) NOT NULL DEFAULT '',
  `domain` varchar(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Sign in history';

-- --------------------------------------------------------

--
-- Структура таблицы `menu`
--

CREATE TABLE `menu` (
`menu_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `parent_id` int(11) unsigned NOT NULL,
  `url` varchar(255) NOT NULL DEFAULT '',
  `title` varchar(1024) NOT NULL,
  `priority` int(11) NOT NULL DEFAULT '0',
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Menu table';

-- --------------------------------------------------------

--
-- Структура таблицы `news`
--

CREATE TABLE `news` (
`news_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `date` date NOT NULL DEFAULT '2015-01-01',
  `title` varchar(1028) NOT NULL,
  `preview` varchar(5000) DEFAULT NULL COMMENT 'Deprecated field for compatibility',
  `body` text,
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='News table';

-- --------------------------------------------------------

--
-- Структура таблицы `pages`
--

CREATE TABLE `pages` (
`page_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `folder_id` int(10) unsigned DEFAULT NULL,
  `title` varchar(1024) NOT NULL,
  `url` varchar(255) NOT NULL DEFAULT '',
  `body` mediumtext,
  `noindex` tinyint(1) NOT NULL DEFAULT '0',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `meta_title` varchar(255) NOT NULL DEFAULT '',
  `meta_description` varchar(255) NOT NULL DEFAULT '',
  `meta_keywords` varchar(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Pages table';

-- --------------------------------------------------------

--
-- Структура таблицы `pages_folders`
--

CREATE TABLE `pages_folders` (
`folder_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Folders for pages';

-- --------------------------------------------------------

--
-- Структура таблицы `payments`
--

CREATE TABLE `payments` (
`payment_id` int(11) unsigned NOT NULL,
  `user_id` int(11) unsigned DEFAULT NULL,
  `site_id` int(10) unsigned DEFAULT NULL,
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sum` decimal(16,2) NOT NULL DEFAULT '0.00',
  `package` varchar(128) NOT NULL DEFAULT '',
  `period` varchar(16) NOT NULL DEFAULT '',
  `status` varchar(16) NOT NULL DEFAULT '',
  `coupon` varchar(64) DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Payments table';

-- --------------------------------------------------------

--
-- Структура таблицы `payments_domains`
--

CREATE TABLE `payments_domains` (
`id` int(11) unsigned NOT NULL,
  `did` int(11) unsigned DEFAULT NULL COMMENT 'domains_reg.id',
  `user_id` int(11) unsigned DEFAULT NULL,
  `sum` double(16,2) NOT NULL DEFAULT '0.00',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `comment` varchar(16384) DEFAULT NULL COMMENT 'queue can be cleared, copy domain name here'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Payments table for domains';

-- --------------------------------------------------------

--
-- Структура таблицы `redirects`
--

CREATE TABLE `redirects` (
`redirect_id` int(10) unsigned NOT NULL,
  `site_id` int(10) unsigned NOT NULL,
  `source` varchar(255) NOT NULL DEFAULT '',
  `destination` varchar(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Table with site''s redirects';

-- --------------------------------------------------------

--
-- Структура таблицы `sites`
--

CREATE TABLE `sites` (
`site_id` int(11) unsigned NOT NULL,
  `user_id` int(11) unsigned NOT NULL,
  `default_domain` int(10) unsigned DEFAULT NULL,
  `default_page` varchar(255) NOT NULL DEFAULT '',
  `template` varchar(64) NOT NULL DEFAULT '',
  `regdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `package` varchar(64) NOT NULL DEFAULT '',
  `paid_till` timestamp NULL DEFAULT NULL,
  `blocked` tinyint(1) NOT NULL DEFAULT '0',
  `disable` varchar(1000) DEFAULT NULL,
  `store_currency` varchar(16) NOT NULL DEFAULT '' COMMENT 'Currency for online store',
  `store_confirmation` text COMMENT 'Text after store ordering',
  `store_freedelivery` mediumint(5) DEFAULT NULL,
  `stat_ga_key` varchar(16) NOT NULL DEFAULT '' COMMENT 'Google Analytics key',
  `stat_ym_key` varchar(16) NOT NULL DEFAULT '' COMMENT 'Yandex.Metrika key',
  `stat_tracking` text COMMENT 'Custom Site Tracking Code',
  `sharing_widget` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Likes and Shares buttons',
  `noindex` tinyint(1) NOT NULL DEFAULT '0',
  `noads` tinyint(1) NOT NULL DEFAULT '0',
  `robots` varchar(1024) NOT NULL DEFAULT '',
  `meta_header` text COMMENT 'Header meta tags',
  `meta_description` varchar(512) NOT NULL DEFAULT '',
  `meta_keywords` varchar(512) NOT NULL DEFAULT '',
  `css` text COMMENT 'Custom CSS for user''s site',
  `title` varchar(255) NOT NULL DEFAULT '',
  `subtitle` varchar(255) NOT NULL DEFAULT '',
  `favicon` varchar(64) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Sites table';

-- --------------------------------------------------------

--
-- Структура таблицы `sites_meta`
--

CREATE TABLE `sites_meta` (
`option_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `html` text COMMENT 'Custom HTML for user''s site',
  `advTop` text,
  `advBottom` text,
  `advNews` text,
  `advMenu` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Deprecated data from Okis';

-- --------------------------------------------------------

--
-- Структура таблицы `store_category`
--

CREATE TABLE `store_category` (
`category_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `parent_id` int(10) unsigned NOT NULL,
  `title` varchar(512) NOT NULL,
  `body` varchar(4000) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `cover` varchar(255) NOT NULL DEFAULT '',
  `sort` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Store categories';

-- --------------------------------------------------------

--
-- Структура таблицы `store_category_relations`
--

CREATE TABLE `store_category_relations` (
`relation_id` int(11) unsigned NOT NULL,
  `category_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `store_checkout`
--

CREATE TABLE `store_checkout` (
`param_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `paymethod` varchar(255) NOT NULL DEFAULT '',
  `param_name` varchar(255) NOT NULL DEFAULT '',
  `param_value` varchar(255) NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Payment methods';

-- --------------------------------------------------------

--
-- Структура таблицы `store_coupon`
--

CREATE TABLE `store_coupon` (
  `coupon_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(11) unsigned NOT NULL,
  `code` varchar(255) NOT NULL DEFAULT '' COMMENT 'Coupon code (name)',
  `limit` int(11) NOT NULL DEFAULT '1',
  `used` int(11) NOT NULL DEFAULT '0',
  `date_start` date DEFAULT NULL,
  `date_end` date DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `discount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `type` enum('ABS','REL') NOT NULL,
  PRIMARY KEY (`coupon_id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COMMENT='Coupons and promocodes';

-- --------------------------------------------------------

--
-- Структура таблицы `store_delivery`
--

CREATE TABLE `store_delivery` (
`delivery_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `price` decimal(10,2) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `store_item`
--

CREATE TABLE `store_item` (
`item_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `cover` varchar(255) NOT NULL DEFAULT '',
  `description` text,
  `body` text,
  `price` decimal(10,2) unsigned NOT NULL DEFAULT '0.00',
  `price_sale` decimal(10,2) unsigned DEFAULT NULL,
  `hidden` tinyint(1) NOT NULL DEFAULT '0',
  `sort` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Products table';

-- --------------------------------------------------------

--
-- Структура таблицы `store_item_info`
--

CREATE TABLE `store_item_info` (
`info_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `value` varchar(5000) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Additional characteristics for products';

-- --------------------------------------------------------

--
-- Структура таблицы `store_item_more`
--

CREATE TABLE `store_item_more` (
`more_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `parent_id` int(11) unsigned NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='See also for products';

-- --------------------------------------------------------

--
-- Структура таблицы `store_item_param`
--

CREATE TABLE `store_item_param` (
`param_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `sort` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Additional parameters that users can chose (like size, etc.)';

-- --------------------------------------------------------

--
-- Структура таблицы `store_item_param_value`
--

CREATE TABLE `store_item_param_value` (
`value_id` int(11) unsigned NOT NULL,
  `param_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `value` varchar(255) NOT NULL DEFAULT '',
  `price` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Available values for Additional parameters';

-- --------------------------------------------------------

--
-- Структура таблицы `store_item_photo`
--

CREATE TABLE `store_item_photo` (
`photo_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `filename` varchar(255) NOT NULL DEFAULT '',
  `title` varchar(1024) NOT NULL DEFAULT '',
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Product photos';

-- --------------------------------------------------------

--
-- Структура таблицы `store_order`
--

CREATE TABLE `store_order` (
  `order_id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `site_id` int(11) unsigned NOT NULL,
  `email` varchar(255) NOT NULL,
  `phone` varchar(255) NOT NULL DEFAULT '',
  `data` varchar(2048) NOT NULL DEFAULT '0',
  `qty` int(11) NOT NULL DEFAULT '0' COMMENT 'Total quantity',
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT 'Total price',
  `promocode` varchar(250) NOT NULL DEFAULT '',
  `promocode_discount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status` enum('NEW','PENDING','DONE','FAIL') NOT NULL DEFAULT 'NEW',
  `delivery_title` varchar(255) DEFAULT NULL,
  `delivery_price` decimal(10,2) unsigned DEFAULT NULL,
  PRIMARY KEY (`order_id`),
  KEY `site_id` (`site_id`),
  CONSTRAINT `store_order_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COMMENT='Store orders';

-- --------------------------------------------------------

--
-- Структура таблицы `store_order_data`
--

CREATE TABLE `store_order_data` (
`data_id` int(11) unsigned NOT NULL,
  `site_id` int(11) unsigned NOT NULL,
  `title` varchar(255) NOT NULL DEFAULT '',
  `required` tinyint(1) NOT NULL DEFAULT '1',
  `hidden` tinyint(1) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы `store_order_item`
--

CREATE TABLE `store_order_item` (
`id` int(11) unsigned NOT NULL,
  `order_id` int(11) unsigned NOT NULL,
  `item_id` int(11) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` varchar(3000) NOT NULL DEFAULT '',
  `params` varchar(1000) NOT NULL DEFAULT '',
  `price` decimal(10,2) NOT NULL DEFAULT '0.00' COMMENT 'Product price',
  `qty` int(11) NOT NULL DEFAULT '0' COMMENT 'Product quantity'
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Products in order';

-- --------------------------------------------------------

--
-- Структура таблицы `users`
--

CREATE TABLE `users` (
`user_id` int(11) unsigned NOT NULL,
  `email` varchar(255) NOT NULL,
  `password` varchar(255) NOT NULL DEFAULT '',
  `balance` decimal(10,2) NOT NULL DEFAULT '0.00',
  `lang` varchar(5) NOT NULL DEFAULT '' COMMENT 'User language',
  `tz` varchar(64) DEFAULT NULL COMMENT 'Time zone',
  `country` char(2) DEFAULT NULL COMMENT '2-letter ISO country code',
  `utm` varchar(255) NOT NULL DEFAULT '' COMMENT 'Field for utm marks (e. g. utm_source, utm_campaign)',
  `affiliate_id` int(11) unsigned DEFAULT NULL,
  `regdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Users table';

--
-- Индексы сохранённых таблиц
--

--
-- Индексы таблицы `affiliate_sites`
--
ALTER TABLE `affiliate_sites`
 ADD PRIMARY KEY (`site_id`), ADD UNIQUE KEY `domain` (`domain`), ADD KEY `affiliate_id` (`affiliate_id`);

--
-- Индексы таблицы `affiliate_stat`
--
ALTER TABLE `affiliate_stat`
 ADD PRIMARY KEY (`stat_id`), ADD KEY `affiliate_id` (`affiliate_id`), ADD KEY `FK_payment_id` (`payment_id`);

--
-- Индексы таблицы `affiliate_users`
--
ALTER TABLE `affiliate_users`
 ADD PRIMARY KEY (`affiliate_id`);

--
-- Индексы таблицы `blocks`
--
ALTER TABLE `blocks`
 ADD PRIMARY KEY (`block_id`), ADD KEY `FK_domain_site` (`site_id`);

--
-- Индексы таблицы `blog_comments`
--
ALTER TABLE `blog_comments`
 ADD PRIMARY KEY (`comment_id`), ADD KEY `post_id` (`post_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `blog_posts`
--
ALTER TABLE `blog_posts`
 ADD PRIMARY KEY (`post_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `domains`
--
ALTER TABLE `domains`
 ADD PRIMARY KEY (`domain_id`), ADD UNIQUE KEY `domain_uniq` (`ascii`), ADD KEY `FK_domain_site` (`site_id`);

--
-- Индексы таблицы `domains_queue`
--
ALTER TABLE `domains_queue`
 ADD PRIMARY KEY (`id`), ADD KEY `FK_did` (`did`);

--
-- Индексы таблицы `domains_reg`
--
ALTER TABLE `domains_reg`
 ADD PRIMARY KEY (`id`), ADD UNIQUE KEY `domain` (`domain`), ADD KEY `status` (`status`), ADD KEY `dt` (`dt`), ADD KEY `dtype_status` (`status`), ADD KEY `FK_reg_domain` (`domain_id`), ADD KEY `FK_reg_site` (`site_id`), ADD KEY `FK_reg_user` (`user_id`);

--
-- Индексы таблицы `events`
--
ALTER TABLE `events`
 ADD PRIMARY KEY (`event_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `form_info`
--
ALTER TABLE `form_info`
 ADD PRIMARY KEY (`form_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `form_questions`
--
ALTER TABLE `form_questions`
 ADD PRIMARY KEY (`form_question_id`), ADD KEY `form_id` (`form_id`,`priority`);

--
-- Индексы таблицы `form_question_options`
--
ALTER TABLE `form_question_options`
 ADD PRIMARY KEY (`form_question_option_id`), ADD KEY `form_question_id` (`form_question_id`);

--
-- Индексы таблицы `forum_posts`
--
ALTER TABLE `forum_posts`
 ADD PRIMARY KEY (`post_id`), ADD KEY `user_id` (`user_id`), ADD KEY `topic_id` (`topic_id`);

--
-- Индексы таблицы `forum_topics`
--
ALTER TABLE `forum_topics`
 ADD PRIMARY KEY (`topic_id`), ADD KEY `user_id` (`user_id`);

--
-- Индексы таблицы `gallery_albums`
--
ALTER TABLE `gallery_albums`
 ADD PRIMARY KEY (`album_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `gallery_photos`
--
ALTER TABLE `gallery_photos`
 ADD PRIMARY KEY (`photo_id`), ADD KEY `album_id` (`album_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `logs`
--
ALTER TABLE `logs`
 ADD PRIMARY KEY (`id`);

--
-- Индексы таблицы `menu`
--
ALTER TABLE `menu`
 ADD PRIMARY KEY (`menu_id`), ADD KEY `site_id` (`site_id`,`priority`);

--
-- Индексы таблицы `news`
--
ALTER TABLE `news`
 ADD PRIMARY KEY (`news_id`), ADD KEY `site_id` (`site_id`), ADD KEY `site_list` (`site_id`,`hidden`,`date`);

--
-- Индексы таблицы `pages`
--
ALTER TABLE `pages`
 ADD PRIMARY KEY (`page_id`), ADD KEY `site_id` (`site_id`), ADD KEY `folder_id` (`folder_id`), ADD KEY `admin_list` (`site_id`,`folder_id`), ADD KEY `admin_search` (`site_id`,`url`);

--
-- Индексы таблицы `pages_folders`
--
ALTER TABLE `pages_folders`
 ADD PRIMARY KEY (`folder_id`), ADD KEY `site_id` (`site_id`), ADD KEY `admin_list` (`site_id`,`title`);

--
-- Индексы таблицы `payments`
--
ALTER TABLE `payments`
 ADD PRIMARY KEY (`payment_id`), ADD UNIQUE KEY `user_promo` (`user_id`,`coupon`), ADD KEY `user_id` (`user_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `payments_domains`
--
ALTER TABLE `payments_domains`
 ADD PRIMARY KEY (`id`), ADD KEY `user_id` (`user_id`), ADD KEY `FK_pdreg` (`did`);

--
-- Индексы таблицы `redirects`
--
ALTER TABLE `redirects`
 ADD PRIMARY KEY (`redirect_id`), ADD KEY `site_id` (`site_id`), ADD KEY `main` (`site_id`,`source`);

--
-- Индексы таблицы `sites`
--
ALTER TABLE `sites`
 ADD PRIMARY KEY (`site_id`), ADD KEY `user_id` (`user_id`), ADD KEY `FK_default_domain` (`default_domain`);

--
-- Индексы таблицы `sites_meta`
--
ALTER TABLE `sites_meta`
 ADD PRIMARY KEY (`option_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_category`
--
ALTER TABLE `store_category`
 ADD PRIMARY KEY (`category_id`), ADD KEY `site_id` (`site_id`), ADD KEY `site_list` (`site_id`,`hidden`,`category_id`), ADD KEY `parent_idx` (`parent_id`);

--
-- Индексы таблицы `store_category_relations`
--
ALTER TABLE `store_category_relations`
 ADD PRIMARY KEY (`relation_id`), ADD UNIQUE KEY `cid-pid` (`category_id`,`item_id`), ADD KEY `FK_store_category` (`category_id`), ADD KEY `FK_store_item` (`item_id`);

--
-- Индексы таблицы `store_checkout`
--
ALTER TABLE `store_checkout`
 ADD PRIMARY KEY (`param_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_coupon`
--
ALTER TABLE `store_coupon`
 ADD PRIMARY KEY (`coupon_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_delivery`
--
ALTER TABLE `store_delivery`
 ADD PRIMARY KEY (`delivery_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_item`
--
ALTER TABLE `store_item`
 ADD PRIMARY KEY (`item_id`), ADD KEY `site_id` (`site_id`), ADD KEY `site_list1` (`site_id`,`title`), ADD KEY `site_list2` (`site_id`,`price`);

--
-- Индексы таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
 ADD PRIMARY KEY (`info_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `store_item_more`
--
ALTER TABLE `store_item_more`
 ADD PRIMARY KEY (`more_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `store_item_param`
--
ALTER TABLE `store_item_param`
 ADD PRIMARY KEY (`param_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `store_item_param_value`
--
ALTER TABLE `store_item_param_value`
 ADD PRIMARY KEY (`value_id`), ADD KEY `param_id` (`param_id`,`item_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `store_item_photo`
--
ALTER TABLE `store_item_photo`
 ADD PRIMARY KEY (`photo_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `store_order`
--
ALTER TABLE `store_order`
 ADD PRIMARY KEY (`order_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_order_data`
--
ALTER TABLE `store_order_data`
 ADD PRIMARY KEY (`data_id`), ADD KEY `site_id` (`site_id`);

--
-- Индексы таблицы `store_order_item`
--
ALTER TABLE `store_order_item`
 ADD PRIMARY KEY (`id`), ADD KEY `order_id` (`order_id`,`item_id`), ADD KEY `item_id` (`item_id`);

--
-- Индексы таблицы `users`
--
ALTER TABLE `users`
 ADD PRIMARY KEY (`user_id`), ADD UNIQUE KEY `email` (`email`), ADD KEY `affiliate_id` (`affiliate_id`);

--
-- AUTO_INCREMENT для сохранённых таблиц
--

--
-- AUTO_INCREMENT для таблицы `affiliate_sites`
--
ALTER TABLE `affiliate_sites`
MODIFY `site_id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `affiliate_stat`
--
ALTER TABLE `affiliate_stat`
MODIFY `stat_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `affiliate_users`
--
ALTER TABLE `affiliate_users`
MODIFY `affiliate_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `blocks`
--
ALTER TABLE `blocks`
MODIFY `block_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `blog_comments`
--
ALTER TABLE `blog_comments`
MODIFY `comment_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `blog_posts`
--
ALTER TABLE `blog_posts`
MODIFY `post_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `domains`
--
ALTER TABLE `domains`
MODIFY `domain_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `domains_queue`
--
ALTER TABLE `domains_queue`
MODIFY `id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `domains_reg`
--
ALTER TABLE `domains_reg`
MODIFY `id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `events`
--
ALTER TABLE `events`
MODIFY `event_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `form_info`
--
ALTER TABLE `form_info`
MODIFY `form_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `form_questions`
--
ALTER TABLE `form_questions`
MODIFY `form_question_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `form_question_options`
--
ALTER TABLE `form_question_options`
MODIFY `form_question_option_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `forum_posts`
--
ALTER TABLE `forum_posts`
MODIFY `post_id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `forum_topics`
--
ALTER TABLE `forum_topics`
MODIFY `topic_id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `gallery_albums`
--
ALTER TABLE `gallery_albums`
MODIFY `album_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `gallery_photos`
--
ALTER TABLE `gallery_photos`
MODIFY `photo_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `logs`
--
ALTER TABLE `logs`
MODIFY `id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `menu`
--
ALTER TABLE `menu`
MODIFY `menu_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `news`
--
ALTER TABLE `news`
MODIFY `news_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `pages`
--
ALTER TABLE `pages`
MODIFY `page_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `pages_folders`
--
ALTER TABLE `pages_folders`
MODIFY `folder_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `payments`
--
ALTER TABLE `payments`
MODIFY `payment_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `payments_domains`
--
ALTER TABLE `payments_domains`
MODIFY `id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `redirects`
--
ALTER TABLE `redirects`
MODIFY `redirect_id` int(10) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `sites`
--
ALTER TABLE `sites`
MODIFY `site_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `sites_meta`
--
ALTER TABLE `sites_meta`
MODIFY `option_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_category`
--
ALTER TABLE `store_category`
MODIFY `category_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_category_relations`
--
ALTER TABLE `store_category_relations`
MODIFY `relation_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_checkout`
--
ALTER TABLE `store_checkout`
MODIFY `param_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_coupon`
--
ALTER TABLE `store_coupon`
MODIFY `coupon_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_delivery`
--
ALTER TABLE `store_delivery`
MODIFY `delivery_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item`
--
ALTER TABLE `store_item`
MODIFY `item_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
MODIFY `info_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item_more`
--
ALTER TABLE `store_item_more`
MODIFY `more_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item_param`
--
ALTER TABLE `store_item_param`
MODIFY `param_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item_param_value`
--
ALTER TABLE `store_item_param_value`
MODIFY `value_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_item_photo`
--
ALTER TABLE `store_item_photo`
MODIFY `photo_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_order`
--
ALTER TABLE `store_order`
MODIFY `order_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_order_data`
--
ALTER TABLE `store_order_data`
MODIFY `data_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `store_order_item`
--
ALTER TABLE `store_order_item`
MODIFY `id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT для таблицы `users`
--
ALTER TABLE `users`
MODIFY `user_id` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- Ограничения внешнего ключа сохраненных таблиц
--

--
-- Ограничения внешнего ключа таблицы `affiliate_sites`
--
ALTER TABLE `affiliate_sites`
ADD CONSTRAINT `affiliate_sites_ibfk_1` FOREIGN KEY (`affiliate_id`) REFERENCES `affiliate_users` (`affiliate_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `affiliate_stat`
--
ALTER TABLE `affiliate_stat`
ADD CONSTRAINT `affiliate_stat_ibfk_1` FOREIGN KEY (`affiliate_id`) REFERENCES `affiliate_users` (`affiliate_id`) ON DELETE CASCADE,
ADD CONSTRAINT `FK_payment_id` FOREIGN KEY (`payment_id`) REFERENCES `payments` (`payment_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `blocks`
--
ALTER TABLE `blocks`
ADD CONSTRAINT `FK_block_site` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `blog_comments`
--
ALTER TABLE `blog_comments`
ADD CONSTRAINT `blog_comments_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `blog_posts` (`post_id`) ON DELETE CASCADE,
ADD CONSTRAINT `blog_comments_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE NO ACTION ON UPDATE NO ACTION;

--
-- Ограничения внешнего ключа таблицы `blog_posts`
--
ALTER TABLE `blog_posts`
ADD CONSTRAINT `blog_posts_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `domains`
--
ALTER TABLE `domains`
ADD CONSTRAINT `FK_domain_site` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `domains_queue`
--
ALTER TABLE `domains_queue`
ADD CONSTRAINT `FK_did` FOREIGN KEY (`did`) REFERENCES `domains_reg` (`id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `domains_reg`
--
ALTER TABLE `domains_reg`
ADD CONSTRAINT `FK_reg_domain` FOREIGN KEY (`domain_id`) REFERENCES `domains` (`domain_id`) ON DELETE SET NULL,
ADD CONSTRAINT `FK_reg_site` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE SET NULL,
ADD CONSTRAINT `FK_reg_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Ограничения внешнего ключа таблицы `events`
--
ALTER TABLE `events`
ADD CONSTRAINT `events_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `form_info`
--
ALTER TABLE `form_info`
ADD CONSTRAINT `sites_idfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `form_questions`
--
ALTER TABLE `form_questions`
ADD CONSTRAINT `form_idfk_1` FOREIGN KEY (`form_id`) REFERENCES `form_info` (`form_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `form_question_options`
--
ALTER TABLE `form_question_options`
ADD CONSTRAINT `form_question_idfk_1` FOREIGN KEY (`form_question_id`) REFERENCES `form_questions` (`form_question_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `forum_posts`
--
ALTER TABLE `forum_posts`
ADD CONSTRAINT `forum_posts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL,
ADD CONSTRAINT `forum_posts_ibfk_2` FOREIGN KEY (`topic_id`) REFERENCES `forum_topics` (`topic_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `forum_topics`
--
ALTER TABLE `forum_topics`
ADD CONSTRAINT `forum_topics_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Ограничения внешнего ключа таблицы `gallery_albums`
--
ALTER TABLE `gallery_albums`
ADD CONSTRAINT `gallery_albums_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `gallery_photos`
--
ALTER TABLE `gallery_photos`
ADD CONSTRAINT `gallery_photos_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE,
ADD CONSTRAINT `gallery_photos_ibfk_2` FOREIGN KEY (`album_id`) REFERENCES `gallery_albums` (`album_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `menu`
--
ALTER TABLE `menu`
ADD CONSTRAINT `menu_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `news`
--
ALTER TABLE `news`
ADD CONSTRAINT `news_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `pages`
--
ALTER TABLE `pages`
ADD CONSTRAINT `pages_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE,
ADD CONSTRAINT `pages_ibfk_2` FOREIGN KEY (`folder_id`) REFERENCES `pages_folders` (`folder_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `pages_folders`
--
ALTER TABLE `pages_folders`
ADD CONSTRAINT `pages_folders_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `payments`
--
ALTER TABLE `payments`
ADD CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL,
ADD CONSTRAINT `payments_ibfk_2` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE SET NULL;

--
-- Ограничения внешнего ключа таблицы `payments_domains`
--
ALTER TABLE `payments_domains`
ADD CONSTRAINT `FK_pdreg` FOREIGN KEY (`did`) REFERENCES `domains_reg` (`id`) ON DELETE SET NULL,
ADD CONSTRAINT `FK_pdu` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `redirects`
--
ALTER TABLE `redirects`
ADD CONSTRAINT `redirects_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `sites`
--
ALTER TABLE `sites`
ADD CONSTRAINT `FK_default_domain` FOREIGN KEY (`default_domain`) REFERENCES `domains` (`domain_id`) ON DELETE SET NULL,
ADD CONSTRAINT `sites_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `sites_meta`
--
ALTER TABLE `sites_meta`
ADD CONSTRAINT `sites_meta_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_category`
--
ALTER TABLE `store_category`
ADD CONSTRAINT `store_category_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_category_relations`
--
ALTER TABLE `store_category_relations`
ADD CONSTRAINT `store_category_relations_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `store_category` (`category_id`) ON DELETE CASCADE,
ADD CONSTRAINT `store_category_relations_ibfk_2` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_checkout`
--
ALTER TABLE `store_checkout`
ADD CONSTRAINT `store_checkout_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_coupon`
--
ALTER TABLE `store_coupon`
ADD CONSTRAINT `store_coupon_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_delivery`
--
ALTER TABLE `store_delivery`
ADD CONSTRAINT `FK_store_delivery_site` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item`
--
ALTER TABLE `store_item`
ADD CONSTRAINT `store_item_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item_info`
--
ALTER TABLE `store_item_info`
ADD CONSTRAINT `store_item_info_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item_more`
--
ALTER TABLE `store_item_more`
ADD CONSTRAINT `store_item_more_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item_param`
--
ALTER TABLE `store_item_param`
ADD CONSTRAINT `store_item_param_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item_param_value`
--
ALTER TABLE `store_item_param_value`
ADD CONSTRAINT `store_item_param_value_ibfk_1` FOREIGN KEY (`param_id`) REFERENCES `store_item_param` (`param_id`) ON DELETE CASCADE,
ADD CONSTRAINT `store_item_param_value_ibfk_2` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_item_photo`
--
ALTER TABLE `store_item_photo`
ADD CONSTRAINT `store_item_photo_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `store_item` (`item_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_order`
--
ALTER TABLE `store_order`
ADD CONSTRAINT `store_order_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_order_data`
--
ALTER TABLE `store_order_data`
ADD CONSTRAINT `store_order_data_ibfk_1` FOREIGN KEY (`site_id`) REFERENCES `sites` (`site_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `store_order_item`
--
ALTER TABLE `store_order_item`
ADD CONSTRAINT `store_order_item_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `store_order` (`order_id`) ON DELETE CASCADE;

--
-- Ограничения внешнего ключа таблицы `users`
--
ALTER TABLE `users`
ADD CONSTRAINT `users_ibfk_1` FOREIGN KEY (`affiliate_id`) REFERENCES `affiliate_users` (`affiliate_id`) ON DELETE SET NULL;
