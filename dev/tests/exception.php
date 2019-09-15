<?php

class CustomException extends Exception {}

function DoSomething() {
    throw new CustomException('Hi There');
}

function Something() {
    $c = 42;
    $d = 12;
    throw new Exception('Boo');
}

Something();
