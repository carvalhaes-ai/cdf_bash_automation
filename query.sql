SELECT id,
	hire_date,
	name,
	department,
	years_of_experience
FROM
	$database.employees a
WHERE $CONDITIONS;
