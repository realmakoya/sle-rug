module Syntax

extend lang::std::Layout;
extend lang::std::Id;

/*
 * Concrete syntax of QL
 */

start syntax Form 
  = "form" Id "{" Question* "}"; 

syntax Question
  = @Foldable Str Id ":" Type //TODO: str; Seperate production for Var?
  | @Foldable Str Id ":" Type "=" Expr 
  | @Foldable Block
  | @Foldable "if" "(" Expr ")" Block "else" Block
  | @Foldable "if" "(" Expr ")" Block
  ; 
  
syntax Block
  = "{" Question* "}" 
  ;

// TODO: +, -, *, /, &&, ||, !, >, <, <=, >=, ==, !=, literals (bool, int, str)
// Think about disambiguation using priorities and associativity
// and use C/Java style precedence rules (look it up on the internet)
// Using associativity rules: https://docs.oracle.com/javase/tutorial/java/nutsandbolts/operators.html
// and https://introcs.cs.princeton.edu/java/11precedence/
syntax Expr 
  = Id \ "true" \ "false" // true/false are reserved keywords.
  | Str
  | Int
  | Bool
  | bracket "(" Expr ")"
  > right "!" Expr
  | right "-" Expr
  > left Expr "*" Expr
  > left Expr "/" Expr //TODO: priorities
  > left Expr "+" Expr
  > left Expr "-" Expr
  > left Expr "\>" Expr //TODO: non assoc
  > left Expr "\<" Expr
  > left Expr "\<=" Expr
  > left Expr "\>=" Expr
  > left Expr "==" Expr
  > left Expr "!=" Expr
  > left Expr "&&" Expr
  > left Expr "||" Expr
  ;
  
  
syntax Type
  = "string"
  | "integer"
  | "boolean" 
  ;  
  
lexical Str = @category="StringLiteral" [\"] ![\"]* [\"]; 

lexical Int = ([\-]?[1-9][0-9]*)|[0];
 
lexical Bool = "true" | "false"; 




