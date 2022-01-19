module Compile

import AST;
import Resolve;
import IO;
import lang::html5::DOM; // see standard library

/*
 * Implement a compiler for QL to HTML and Javascript
 *
 * - assume the form is type- and name-correct
 * - separate the compiler in two parts form2html and form2js producing 2 files
 * - use string templates to generate Javascript
 * - use the HTML5Node type and the `str toString(HTML5Node x)` function to format to string
 * - use any client web framework (e.g. Vue, React, jQuery, whatever) you like for event handling
 * - map booleans to checkboxes, strings to textfields, ints to numeric text fields
 * - be sure to generate uneditable widgets for computed questions!
 * - if needed, use the name analysis to link uses to definitions
 */

 int ifC = 0;

void compile(AForm f) {
  writeFile(f.src[extension="js"].top, form2js(f));
  writeFile(f.src[extension="html"].top, toString(form2html(f)));
}

str getType(AType \type) {
	switch(\type) {
		case strType(): return "text";
		case intType(): return "number";
		case boolType(): return "checkbox";
		default: throw "Unknown type";
	}
}

HTML5Node genNode(question(str quest, AId varId, AType varType)) {
	return div(label(\for(varId.name), quest), 
		input(\type(getType(varType)), name(varId.name), id(varId.name), onchange("updateForm()")));
}

HTML5Node genNode(compQuestion(str quest, AId varId, AType varType, AExpr varExpr)) {
	return div(label(\for(varId.name), quest), 
		input(\type(getType(varType)), name(varId.name), id(varId.name), disabled("")));
}

HTML5Node genNode(block(list[AQuestion] quests)) {
	list[HTML5Node] subQuests = [];
	for (q <- quests) {
		subQuests += genNode(q);
	}
	return div(subQuests); //TODO: name?
}

HTML5Node genNode(ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock)) {
	HTML5Node ifBlQuests = genNode(ifBlock);
	list[HTML5Node] elseBlQuests = genNode(elseBlock);
	ifC += 1;
	return section(id("@ifElse<ifC>"), 
			section(id("@ifBlock<ifC>"), ifBlQuests), section(id("@elseBlock<ifC>"), elseBlQuests));
}

HTML5Node genNode(ifThen(AExpr guard, AQuestion ifBlock)) {
	HTML5Node ifBlQuests = genNode(ifBlock);
	ifC += 1;
	return section(id("@ifThen<ifC>"), 
			section(id("@ifBlock<ifC>"), ifBlQuests));
}

default HTML5Node genNode(AQuestion q) {
	return div();
}

list[HTML5Node] genForm(AForm f) {
	list[HTML5Node] elems = [];
	for (q <- f.questions) {
		elems += genNode(q);
	}
	return elems;
}

HTML5Node form2html(AForm f) {
  FORM = section(class("form"), form(genForm(f)));
  TEST = html(head(title(f.name), script(src(f.src[extension="js"].file))),
  			body(FORM));
  //println(toString(TEST));
  TEST2 = html(head(title(f.name)), body(FORM)); //TODO: submit button
  //println(toString(TEST2));
  return TEST;
}

str getDefaultType(AType varType) {
	switch(varType) {
		case strType(): return "";
		case intType(): return "0";
		case boolType(): return "false"; 
		default: return "";
	}
}

str initVars(AForm f) {
	str varDecl = "";
	visit(f) {
		case question(_, AId varId, AType varType): {
			//println(getDefaultType(varType));
			varDecl += "var <varId.name> = <getDefaultType(varType)>;\n";
		}
		case compQuestion(_, AId varId, AType varType, _): {
			varDecl += "var <varId.name> = <getDefaultType(varType)>;\n";
		}
	}
	varDecl += "\n";
	return varDecl;
}

str genExpr(AExpr expr) {
	switch(expr) {
		case ref(id(str x)): return "<x>";
		case strlit(str strVal): return "\"<strVal>\"";
		case intlit(int intVal): return "<intVal>";
		case boollit(bool boolVal): return "<boolVal>";
		case not(AExpr expr): return "!(<genExpr(expr)>)";
		case neg(AExpr expr): return "-(<genExpr(expr)>)";
		case mul(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> * <genExpr(rhs)>";
		case div(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> / <genExpr(rhs)>";
		case add(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> + <genExpr(rhs)>";
		case sub(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> - <genExpr(rhs)>";
		case gt(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> \> <genExpr(rhs)>";
		case lt(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> \< <genExpr(rhs)>";
		case lteq(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> \<= <genExpr(rhs)>";
		case gteq(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> \>= <genExpr(rhs)>";
		case eql(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> == <genExpr(rhs)>";
		case neq(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> != <genExpr(rhs)>";
		case and(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> && <genExpr(rhs)>";
		case or(AExpr lhs, AExpr rhs): return "<genExpr(lhs)> || <genExpr(rhs)>";
	}
}

str compQuestions(AForm f) {
	str updates = "";
	visit(f) {
		case compQuestion(_, AId varId, _, AExpr varExpr): updates += "<varId.name> = <genExpr(varExpr)>;\n";
	}
	return "function updateCompQuests() {\n <updates> }\n";
}

str genAssign(AId varId, AType varType) {
	str out = "var temp = document.getElementById(\"<varId.name>\");\n";
	switch(varType) {
		case intType(): return out += "<varId.name> = Number(temp.value);\n";
		case boolType(): return out += "<varId.name> = temp.checked;\n";
		default: return out += "<varId.name> = temp.value;\n";
	}
	return out;
}

str genCompute(AId varId, AType varType, AExpr varExpr) {
	str out = "var temp = document.getElementById(\"<varId.name>\");\n";
	out += "<varId.name> = <genExpr(varExpr)>;\n";
	switch(varType) {
		case boolType():
			return out += "temp.checked = <varId.name>;\n";
		default: return out += "temp.value = <varId.name>;\n";
	}
}

str genFormUpdate(AForm f) {
	str updates = "";
	int ifCount = 1;
	visit(f) {
		case question(_, AId varId, AType varType): {
			updates += genAssign(varId, varType);
		}
		case compQuestion(_, AId varId, AType varType, AExpr varExpr): {
			updates += genCompute(varId, varType, varExpr);
		}
		case ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock): {
			println(guard);
			updates += "";
			
			updates += "var temp = document.getElementById(\"@ifElse<ifCount>\");
					   'if (<genExpr(guard)>) {
					   'var temp = document.getElementById(\"@ifBlock<ifCount>\");	
					   'temp.style.display = \"block\";	
					   'var temp = document.getElementById(\"@elseBlock<ifCount>\");
					   'temp.style.display = \"none\";	
					   '} else {
					   'var temp = document.getElementById(\"@elseBlock<ifCount>\");
					   'temp.style.display = \"block\";	
					   'var temp = document.getElementById(\"@ifBlock<ifCount>\");	
					   'temp.style.display = \"none\";	
					   }\n"; //TODO: only do calculations of computed based off conditionals
			ifCount += 1;
		}
		case ifThen(AExpr guard, AQuestion ifBlock): {
			updates += "";
			
			updates += "var temp = document.getElementById(\"@ifElse<ifCount>\");
					   'if (<genExpr(guard)>) {
					   'var temp = document.getElementById(\"@ifBlock<ifCount>\");	
					   'temp.style.display = \"block\";	
					   '} else {
					   'var temp = document.getElementById(\"@ifBlock<ifCount>\");	
					   'temp.style.display = \"none\";	
					   }\n"; //TODO: only do calculations of computed based off conditionals
			ifCount += 1;
		}
	}
	return "function updateForm() {\n console.log(\"updating\"); \n<updates>}\n";
}

str form2js(AForm f) {
  //str js = "const _input = document.querySelector(\'input\');
  //		   '_input.addEventListener(\'input\', updateInput);
  //		   'function updateInput(e) {
  //		   '	updateForm();
  //		   '}\n";
  return initVars(f) + genFormUpdate(f);
}
