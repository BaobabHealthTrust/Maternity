delimiter $$

CREATE TABLE `birth_report` (
  `birth_report_id` int(11) NOT NULL AUTO_INCREMENT,
  `created_by` int(11) NOT NULL,
  `sent_by` int(11) DEFAULT NULL,
  `person_id` int(11) DEFAULT NULL,
  `date_created` datetime DEFAULT NULL,
  `acknowledged` datetime DEFAULT NULL,
  `date_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`birth_report_id`),
  UNIQUE KEY `idbirth_report_UNIQUE` (`birth_report_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=latin1 COMMENT='A tracker for birth report transactions. Each submitted repo'$$


