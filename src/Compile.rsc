module Compile

import AST;
import Resolve;
import String;
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

HTML5Node genNode(question(str quest, AId varId, AType varType), str parId) {
	return div(label(\for(varId.name), quest), 
		input(\type(getType(varType)), name(varId.name), id(parId + ":" + varId.name), onchange("updateForm()")));
}

HTML5Node genNode(compQuestion(str quest, AId varId, AType varType, AExpr varExpr), str parId) {
	return div(label(\for(varId.name), quest), 
		input(\type(getType(varType)), name(varId.name), id(parId + ":" + varId.name), disabled("")));
}

HTML5Node genNode(block(list[AQuestion] quests), str parId) {
	list[HTML5Node] subQuests = [];
	for (q <- quests) {
		subQuests += genNode(q, parId);
	}
	return div(subQuests); //TODO: name?
}

HTML5Node genNode(ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock), str parId) {
	ifC += 1;
	str ifId = parId + ":" + "$ifBlock<ifC>";
	str elseId = parId + ":" + "$elseBlock<ifC>";
	HTML5Node ifBlQuests = genNode(ifBlock, ifId);
	HTML5Node elseBlQuests = genNode(elseBlock, elseId);
	return section(id(parId + ":$ifElse<ifC>"), 
			section(id(ifId), ifBlQuests), section(id(elseId), elseBlQuests));
}

HTML5Node genNode(ifThen(AExpr guard, AQuestion ifBlock), str parId) {
	ifC += 1;
	str ifId = parId + ":" + "$ifBlock<ifC>";
	HTML5Node ifBlQuests = genNode(ifBlock, ifId);
	return section(id(parId + ":" + "$ifThen<ifC>"), 
			section(id(ifId), ifBlQuests));
}

default HTML5Node genNode(AQuestion q) {
	return div();
}

list[value] genForm(AForm f) {
	list[value] elems = [id(f.name)];
	for (q <- f.questions) {
		elems += genNode(q, "$form");
	}
	elems += button("Submit", \type("button"), onclick("submitForm()"));
	return elems;
}

HTML5Node form2html(AForm f) {
  ifC = 0;
  FORM = section(id("$form"), form(genForm(f)));
  println(toString(FORM));
  HTML = html(head(title(f.name), script(src(f.src[extension="js"].file))),
  			body(onload("updateForm()"), FORM));
  return HTML;
}

str getDefaultType(AType varType) {
	switch(varType) {
		case strType(): return "";
		case intType(): return "0";
		case boolType(): return "false"; 
		default: return "";
	}
}

str initVars(RefGraph refGraph) {
	set[str] varDecls = {};
	for (def <- refGraph<1>) {
		varDecls += "var <def.name>;\n";
	}
	//varDecl += "\n";
	return ("" | it + varDecl | varDecl <- varDecls) + "\n";
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

str genAssign(AId varId, AType varType, str parId) {
	str out = "var $temp = document.getElementById(\"<parId>:<varId.name>\");\n";
	switch(varType) {
		case intType(): return out += "<varId.name> = Number($temp.value);\n";
		case boolType(): return out += "<varId.name> = $temp.checked;\n";
		default: return out += "<varId.name> = $temp.value;\n";
	}
	return out;
}

str genCompute(AId varId, AType varType, AExpr varExpr, str parId) {
	str out = "var $temp = document.getElementById(\"<parId>:<varId.name>\");\n";
	out += "<varId.name> = <genExpr(varExpr)>;\n";
	switch(varType) {
		case boolType():
			return out += "$temp.checked = <varId.name>;\n";
		default: return out += "$temp.value = <varId.name>;\n";
	}
}

str genFormUpdate(question(_, AId varId, AType varType), str parId) {
	return genAssign(varId, varType, parId);
}

str genFormUpdate(compQuestion(_, AId varId, AType varType, AExpr varExpr), str parId) {
	return genCompute(varId, varType, varExpr, parId);
}

str genFormUpdate(block(list[AQuestion] quests), str parId) {
	//println(quests);
	return ("" | it + genFormUpdate(q, parId) | q <- quests) + "\n";
}

str genFormUpdate(ifElse(AExpr guard, AQuestion ifBlock, AQuestion elseBlock), str parId) {
	ifC += 1;
	str ifId = "<parId>:$ifBlock<ifC>";
	str elseId = "<parId>:$elseBlock<ifC>";	
	str ifBl = "$ifBl<ifC>";
	str elseBl = "$elseBl<ifC>";
	return  "var <ifBl> = document.getElementById(\"<ifId>\");
			'var <elseBl> = document.getElementById(\"<elseId>\");
			'if (<genExpr(guard)>) {
			'	<genFormUpdate(ifBlock, ifId)>
			'	<ifBl>.style.display = \"block\";
			'	<elseBl>.style.display = \"none\";
			'} else {
			'	<genFormUpdate(elseBlock, elseId)>
			'	<ifBl>.style.display = \"none\";
			'	<elseBl>.style.display = \"block\";
			'}\n";
}

str genFormUpdate(ifThen(AExpr guard, AQuestion ifBlock), str parId) {
	ifC += 1;
	str ifId = "<parId>:$ifBlock<ifC>";
	str ifBl = "$ifBl<ifC>";
	return  "var <ifBl> = document.getElementById(\"<ifId>\");
			'if (<genExpr(guard)>) {
			'	<genFormUpdate(ifBlock, ifId)>
			'	<ifBl>.style.display = \"block\";
			'} else {
			'	<ifBl>.style.display = \"none\";
			'}\n";
}

str genFormUpdate(AForm f) {
	str updates = ("" | it + genFormUpdate(q, "$form") | q <- f.questions);
	return "function updateForm() {\n<updates>}\n";
}

str genSubmitForm(RefGraph refGraph, str frmName) {
	set[str] vars = {"<def.name>" | def <- refGraph<1>};
	str varObj = "var $outputObj = new Object();\n";
	varObj = (varObj | it + "$outputObj.<varName> = <varName>;\n" | varName <- vars);
	return "function submitForm() {
		   ' 	<varObj>
		   '	document.getElementById(\"<frmName>\").reset();
		   '	return JSON.stringify($outputObj);
		   '}";
}

str form2js(AForm f) {
  ifC = 0;
  //str js = "const _input = document.querySelector(\'input\');
  //		   '_input.addEventListener(\'input\', updateInput);
  //		   'function updateInput(e) {
  //		   '	updateForm();
  //		   '}\n";
  RefGraph refGraph = resolve(f);
  return initVars(refGraph) + genFormUpdate(f) + genSubmitForm(refGraph, f.name);
}
