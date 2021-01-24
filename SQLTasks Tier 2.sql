/* QUESTIONS 
/* Q1: Some of the facilities charge a fee to members, but some do not.
Write a SQL query to produce a list of the names of the facilities that do. */

SELECT name 
FROM Facilities
WHERE membercost > 0;



/* Q2: How many facilities do not charge a fee to members? */

SELECT count(*) FROM Facilities WHERE membercost = 0.0;

/* Q3: Write an SQL query to show a list of facilities that charge a fee to members,
where the fee is less than 20% of the facility's monthly maintenance cost.
Return the facid, facility name, member cost, and monthly maintenance of the
facilities in question. */

SELECT name, membercost, monthlymaintenance
FROM Facilities
WHERE (membercost > 0 
	AND membercost < 0.2 * monthlymaintenance);

/* Q4: Write an SQL query to retrieve the details of facilities with ID 1 and 5.
Try writing the query without using the OR operator. */

SELECT * FROM Facilities WHERE facid IN (1, 5);


/* Q5: Produce a list of facilities, with each labelled as
'cheap' or 'expensive', depending on if their monthly maintenance cost is
more than $100. Return the name and monthly maintenance of the facilities
in question. */

SELECT name, 
	monthlymaintenance,
	(CASE WHEN monthlymaintenance <= 100 THEN 'cheap'
		 ELSE 'expensive' END) AS cheap_or_expensive
FROM Facilities;



/* Q6: You'd like to get the first and last name of the last member(s)
who signed up. Try not to use the LIMIT clause for your solution. */
SELECT firstname, surname 
FROM Members
WHERE joindate = (SELECT MAX(joindate)
                   FROM Members)

/* Q7: Produce a list of all members who have used a tennis court.
Include in your output the name of the court, and the name of the member
formatted as a single column. Ensure no duplicate data, and order by
the member name. */

SELECT name_of_court, member
FROM 
    (
    SELECT memid, f.name AS name_of_court
	FROM Bookings AS b
	    INNER JOIN Facilities AS f
	        USING (facid)
	WHERE f.name LIKE 'Tennis Court%'
    ) AS tennis_court_bookings
	INNER JOIN 
    (
    SELECT
        DISTINCT CONCAT(firstname, ' ', surname) AS member,
        memid
    FROM Members
    ) AS tennis_players
	USING (memid)
GROUP BY name_of_court, member
ORDER BY member;

/* Q8: Produce a list of bookings on the day of 2012-09-14 which
will cost the member (or guest) more than $30. Remember that guests have
different costs to members (the listed costs are per half-hour 'slot'), and
the guest user's ID is always 0. Include in your output the name of the
facility, the name of the member formatted as a single column, and the cost.
Order by descending cost, and do not use any subqueries. */

WITH facility_member_costs AS 
    (   
    SELECT
        name AS facility,
        CONCAT(firstname, ' ', surname) AS member, 
        CASE WHEN memid = 0 THEN SUM(guestcost)
        ELSE SUM(membercost) END AS member_facility_cost_today
    FROM Bookings 
        JOIN Facilities USING (facid) 
        JOIN Members USING (memid)
    WHERE starttime LIKE '2012-09-14%'
    GROUP BY facility, member
    )
SELECT * 
FROM facility_member_costs
WHERE member_facility_cost_today > 30;

/* Q9: This time, produce the same result as in Q8, but using a subquery. */

SELECT *
FROM 
    (   
    SELECT
        name AS facility,
        CONCAT(firstname, ' ', surname) AS member, 
        CASE WHEN memid = 0 THEN SUM(guestcost)
        ELSE SUM(membercost) END AS member_facility_cost_today
    FROM Bookings 
        JOIN Facilities USING (facid) 
        JOIN Members USING (memid)
    WHERE starttime LIKE '2012-09-14%'
    GROUP BY facility, member
    ) as facility_member_costs
WHERE member_facility_cost_today > 30;


/* PART 2: SQLite

Export the country club data from PHPMyAdmin, and connect to a local SQLite instance from Jupyter notebook 
for the following questions.  

QUESTIONS:
/* Q10: Produce a list of facilities with a total revenue less than 1000.
The output of facility name and total revenue, sorted by revenue. Remember
that there's a different cost for guests and members! */

WITH 
    facilities_bookings AS
        (
        SELECT 
            name AS facility_name,
            membercost,
            guestcost,
            memid
        FROM Bookings
            INNER JOIN
            Facilities USING (facid)
        ),
    guest_facilities_bookings AS
        (
        SELECT 
            facility_name,
            guestcost AS cost,
            memid
        FROM facilities_bookings
        WHERE memid = 0
        ),
    member_facilities_bookings AS
        (
        SELECT 
            facility_name,
            membercost AS cost,
            memid
        FROM facilities_bookings
        WHERE memid != 0
        ),
    guest_facility_revenue AS 
        (
        SELECT 
            facility_name,
            SUM(cost) AS revenue_from_guests
        FROM guest_facilities_bookings
        GROUP BY facility_name
        ),
    member_facility_revenue AS 
        (
        SELECT 
            facility_name,
            SUM(cost) AS revenue_from_members
        FROM member_facilities_bookings
        GROUP BY facility_name
        ),
    facilities_revenue AS
        (
        SELECT *
        FROM guest_facility_revenue 
            JOIN 
            member_facility_revenue USING (facility_name)
        )
SELECT 
    facility_name,
    (revenue_from_guests + revenue_from_members) AS total_revenue
FROM facilities_revenue
WHERE total_revenue < 1000;

/* Q11: Produce a report of members and who recommended them in alphabetic surname,firstname order */
SELECT 
    m1.surname || ', ' || m1.firstname AS member,
    m2.surname || ', ' || m2.firstname AS referrer
FROM Members AS m1
    JOIN
    Members AS m2 
        ON m1.recommendedby = m2.memid
ORDER BY member;

/* Q12: Find the facilities with their usage by member, but not guests */
WITH 
    mem_fac_book AS
        (
        SELECT *
        FROM Bookings
            INNER JOIN
            Facilities USING (facid)
            INNER JOIN
            Members USING (memid)
        ),
    mem_fac_book_ex_guests AS
        (
        SELECT * 
        FROM mem_fac_book
        WHERE memid != 0
        ),
    facilities_usage_ex_guests_by_member_and_facility AS
        (
        SELECT 
            name AS facility,
            surname || ', ' || firstname AS member,
            COUNT(*) AS "usage (by number of bookings)",
            COUNT(*)*membercost AS "usage (by costs paid)"
        FROM mem_fac_book_ex_guests
        GROUP BY facility, member
        )
SELECT *
FROM facilities_usage_ex_guests_by_member_and_facility;

/* Q13: Find the facilities usage by month, but not guests */

WITH 
    mem_fac_book AS
        (
        SELECT *
        FROM Bookings
            INNER JOIN
            Facilities USING (facid)
            INNER JOIN
            Members USING (memid)
        ),
    mem_fac_book_ex_guests AS
        (
        SELECT * 
        FROM mem_fac_book
        WHERE memid != 0
        ),
    facilities_usage_ex_guests_by_month AS
        (
        SELECT 
            STRFTIME('%m', starttime) AS month,
            COUNT(*) AS "usage (by number of bookings)",
            COUNT(*)*membercost AS "usage (by costs paid)"
        FROM mem_fac_book_ex_guests
        GROUP BY month
        )
SELECT *
FROM facilities_usage_ex_guests_by_month;
