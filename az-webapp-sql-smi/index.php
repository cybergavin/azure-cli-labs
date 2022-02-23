 <!-- 
	 Cybergavin - 22-FEB-2022
	 Adapted from https://github.com/uglide/azure-content/blob/master/articles/app-service-web/web-sites-php-sql-database-deploy-use-git.md
	 Modified original to make it a single-page PHP web application and display the connection string.
-->
 <html>
 <head>
 <Title>Registration Form - PHP-MSSQL Demo</Title>
 <style type="text/css">
 	body { background-color: #fff; border-top: solid 10px #000;
 	    color: #333; font-size: .85em; margin: 20; padding: 20;
 	    font-family: "Segoe UI", Verdana, Helvetica, Sans-Serif;
 	}
 	h1, h2, h3,{ color: #000; margin-bottom: 0; padding-bottom: 0; }
 	h1 { font-size: 2em; }
 	h2 { font-size: 1.75em; }
 	h3 { font-size: 1.2em; }
 	table { margin-top: 0.75em; }
 	th { font-size: 1.2em; text-align: left; border: none; padding-left: 0; }
 	td { padding: 0.25em 2em 0.25em 0em; border: 0 none; }
 </style>
 </head>
 <body>
<p align="justify">
	This sample PHP demo web application (adapted from <a href="https://github.com/uglide/azure-content/blob/master/articles/app-service-web/web-sites-php-sql-database-deploy-use-git.md" target="_blank">here</a>) may be used with the accompanying guidelines in this git repo, for deployment on an <b>Azure App Service Plan</b> with an <b>Azure SQL Database</b> (connection enabled by a <b>system-assigned managed identity</b>). 
</p>
<br /> 
<?php
// Obtain connection details from environment variables.
$db_server = getenv("DB_SERVER");
$db_name = getenv("DB_NAME");
$connectionString = "sqlsrv:server=$db_server;Database=$db_name;Authentication=ActiveDirectoryMsi;";
echo "The <b>Connection string</b> used for Azure SQL with a system-assigned managed identity is : <font color=\"green\">\"".$connectionString."\"</font>"
?>
<br /><br />
<hr />
<br />
 <u><h2>Register here!</h2></u>
 <p>Fill in your name and email address, then click <strong>Submit</strong> to register.</p>
 <form method="post" action="index.php" enctype="multipart/form-data" >
       Name  <input type="text" name="name" id="name"/></br></br>
       Email <input type="text" name="email" id="email"/></br></br></br>
       <input type="submit" name="submit" value="Submit" />
 </form>
 <?php
 // Connect to database using a user-assigned managed identity. Obtain connection details from environment variables.
 //$db_server = getenv("DB_SERVER");
 //$db_name = getenv("DB_NAME");

try {
	//$connectionInfo = "Database = $db_name; Authentication = ActiveDirectoryMsi;";
	$conn = new PDO($connectionString);
    $conn->setAttribute( PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION );
 }
 catch(Exception $e){
 	die(var_dump($e));
 }
 // Create table if it does not exist
 try {
	 $sql_create = "IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='registration_tbl' and xtype='U')
	 					CREATE TABLE [dbo].[registration_tbl](
						[id] [int] IDENTITY(1,1) NOT NULL,
						[name] [varchar](30) NULL,
						[email] [varchar](30) NULL,
						[date] [date] NULL
	 					)";
     $stmt = $conn->query($sql_create);
 }
 catch(Exception $e) {
	die(var_dump($e));
}
// Insert values from HTTP POST
  if(!empty($_POST)) {
 try {
 	$name = $_POST['name'];
 	$email = $_POST['email'];
 	$date = date("Y-m-d");
 	// Insert data
 	$sql_insert = "INSERT INTO registration_tbl (name, email, date) 
 				   VALUES (?,?,?)";
 	$stmt = $conn->prepare($sql_insert);
 	$stmt->bindValue(1, $name);
 	$stmt->bindValue(2, $email);
 	$stmt->bindValue(3, $date);
 	$stmt->execute();
 }
 catch(Exception $e) {
 	die(var_dump($e));
 }
 echo "<h3>Your're registered!</h3>";
 }
 // Print contents of table
 $sql_select = "SELECT * FROM registration_tbl";
 $stmt = $conn->query($sql_select);
 $registrants = $stmt->fetchAll(); 
 if(count($registrants) > 0) {
 	echo "<h2>People who are registered:</h2>";
 	echo "<table>";
 	echo "<tr><th>Name</th>";
 	echo "<th>Email</th>";
 	echo "<th>Date</th></tr>";
 	foreach($registrants as $registrant) {
 		echo "<tr><td>".$registrant['name']."</td>";
 		echo "<td>".$registrant['email']."</td>";
 		echo "<td>".$registrant['date']."</td></tr>";
     }
  	echo "</table>";
 } else {
 	echo "<h3>No one is currently registered.</h3>";
 }
 ?>
 </body>
 </html>