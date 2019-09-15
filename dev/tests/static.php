<?php

class C {
  private static $bar;

  public static function test() {
    self::$bar = 'moo';
  }

  public static function moo() {
    return self::$bar;
  }
}

C::test();

C::moo();

