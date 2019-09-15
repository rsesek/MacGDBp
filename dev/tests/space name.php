<?php

function OK() {
  print 'This is OK';
  foreach ($_SERVER AS $k => $v) {
    print "$k ==> $v";
  }
}

OK();
