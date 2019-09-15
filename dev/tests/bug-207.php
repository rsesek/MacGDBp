<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<meta http-equiv="Content-type" content="text/html; charset=utf-8"/>
<title>Title</title>

</head>
<body id="body">
<form action="#" method="post" accept-charset="utf-8" id="myform">
<?php for ($i=0;$i<100;$i++): ?>
<label for="form-data-<?php echo $i ?>"><?php echo "Data $i" ?></label>
<input type="text" name="form[data::<?php echo $i ?>]" value="<?php echo $_POST['form']["data::$i"] ?>x<?= $i ?>" id="form-data-<?php echo $i ?>"/>
<?php endfor?>

<p><input type="submit" value="Submit →"/></p>
</form>
<?php var_dump($_POST) ?>
</body>
</html>
