////////////////////////////////////////////////////////////////////////////////
// Copyright 2010 Michael Schmalle - Teoti Graphix, LLC
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
// http://www.apache.org/licenses/LICENSE-2.0 
// 
// Unless required by applicable law or agreed to in writing, software 
// distributed under the License is distributed on an "AS IS" BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and 
// limitations under the License
// 
// Author: Michael Schmalle, Principal Architect
// mschmalle at teotigraphix dot com
////////////////////////////////////////////////////////////////////////////////

package org.teotigraphix.as3builder.impl
{

/*

buildContainerStart( compilation-unit ) //
buildContainerStart( package )          // "package"
buildNode( name )                       // [\s] "my.domain.core" [\s]
buildContainerStart( content )          // "{" [\n]
buildContainerStart( class )            // "class"
buildNode( name )                       // [\s] "A" [\s]
buildNode( content )                    // "{" [\n]
buildContainerEnd( class )              // ""
buildContainerEnd( content )            // "} " [\n]
buildContainerEnd( package )            // ""
buildNode( content )                    // "}" [\n]
buildContainerEnd( compilation-unit )   // ""

*/

import org.teotigraphix.as3nodes.api.ISourceFile;
import org.teotigraphix.as3parser.api.AS3NodeKind;
import org.teotigraphix.as3parser.api.ASDocNodeKind;
import org.teotigraphix.as3parser.api.IParserNode;
import org.teotigraphix.as3parser.api.KeyWords;
import org.teotigraphix.as3parser.api.Operators;
import org.teotigraphix.as3parser.core.Token;
import org.teotigraphix.as3parser.utils.ASTUtil;

/**
 * TODO DOCME
 * 
 * @author Michael Schmalle
 * @copyright Teoti Graphix, LLC
 * @productversion 1.0
 */
public class BuilderFactory
{
	//--------------------------------------------------------------------------
	//
	//  Private :: Variables
	//
	//--------------------------------------------------------------------------
	
	/**
	 * @private
	 */
	private var indent:int = 0;
	
	/**
	 * @private
	 */
	private var lastToken:Token;
	
	//--------------------------------------------------------------------------
	//
	//  Protected :: Properties
	//
	//--------------------------------------------------------------------------
	
	//----------------------------------
	//  state
	//----------------------------------
	
	/**
	 * @private
	 */
	private var _state:String;
	
	/**
	 * The current node state in the builder.
	 */
	protected function get state():String
	{
		return _state;
	}
	
	/**
	 * @private
	 */	
	protected function set state(value:String):void
	{
		if (value == AS3NodeKind.COMPILATION_UNIT 
			|| value == AS3NodeKind.PACKAGE
			||value == AS3NodeKind.CLASS
			||value == AS3NodeKind.INTERFACE)
		{
			_state = value;
		}
	}
	
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------
	
	/**
	 * Constructor.
	 */
	public function BuilderFactory()
	{
		super();
	}
	
	//--------------------------------------------------------------------------
	//
	//  Public API :: Methods
	//
	//--------------------------------------------------------------------------
	
	/**
	 * @private
	 */
	public function buildTest(ast:IParserNode):String
	{
		// now I need to figure out how to efficently and dynamicly 
		// loop through all children and build their nodes accordingly
		if (!ast.isKind(AS3NodeKind.COMPILATION_UNIT))
		{
			throw new Error("root must be compilation-unit");
		}
		
		var sb:String = "";
		
		state = AS3NodeKind.COMPILATION_UNIT;
		
		var tokens:Vector.<Token> = build(ast);
		
		for each (var token:Token in tokens)
		{
			sb += token.text;
		}
		
		return sb;
	}
	
	/**
	 * Builds a String representation of the AST found in the source file.
	 * 
	 * @param file An ISourceFile containing complete AST to build.
	 * @return A String containg the built source code.
	 */
	public function buildFile(file:ISourceFile):String
	{
		return buildTest(file.compilationNode.node);
	}
	
	/**
	 * Builds a Token Vector representation of the AST found in the source file.
	 * 
	 * @param file An ISourceFile containing complete AST to build.
	 * @return A Vector full of Tokenized AST mirroring the source code.
	 */
	public function buildTokens(file:ISourceFile):Vector.<Token>
	{
		var ast:IParserNode = file.compilationNode.node;
		
		if (!ast.isKind(AS3NodeKind.COMPILATION_UNIT))
		{
			throw new Error("root must be compilation-unit");
		}
		
		state = AS3NodeKind.COMPILATION_UNIT;
		
		var tokens:Vector.<Token> = build(ast);
		
		return tokens;
	}
	
	/**
	 * @private
	 */	
	protected function build(ast:IParserNode, tokens:Vector.<Token> = null):Vector.<Token>
	{
		state = ast.kind;
		
		if (tokens == null)
			tokens = new Vector.<Token>();
		
		if (state != AS3NodeKind.COMPILATION_UNIT)
		{
			addToken(tokens, buildContainerBeforeStartNewline(ast));
			addToken(tokens, buildContainerStart(ast));
			addToken(tokens, buildContainerAfterStartNewline(ast));
		}
		
		var len:int = ast.numChildren;
		if (len > 0)
		{
			for (var i:int = 0; i < len; i++)
			{
				var node:IParserNode = ast.children[i] as IParserNode;
				
				if (node.isKind(AS3NodeKind.PACKAGE))
				{
					buildPackage(node, tokens);
				}
				else if (node.isKind(AS3NodeKind.CLASS))
				{
					buildClass(node, tokens);
				}
				else if (node.isKind(AS3NodeKind.INTERFACE))
				{
					buildInterface(node, tokens);
				}
				else if (node.isKind(AS3NodeKind.FUNCTION))
				{
					buildFunction(node, tokens);
					if (i < len - 1)
						addToken(tokens, newNewLine());
				}
				else
				{
					tokens = build(node, tokens);
				}
			}
		}
		
		if (state != AS3NodeKind.COMPILATION_UNIT)
		{
			addToken(tokens, buildContainerEndNewline(ast));
			addToken(tokens, buildContainerEnd(ast));
		}
		
		if (ast.numChildren == 0 && state != AS3NodeKind.PACKAGE)
		{
			addToken(tokens, buildStartSpace(ast));
			addToken(tokens, buildNode(ast));
			addToken(tokens, buildEndSpace(ast));
		}
		
		return tokens;
	}
	
	/**
	 * node is (package)
	 */
	private function buildPackage(node:IParserNode, tokens:Vector.<Token>):void
	{
		// package
		addToken(tokens, newPackage());
		addToken(tokens, newSpace());
		// name
		var name:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, node);
		if (name.stringValue != null)
		{
			addToken(tokens, newToken(name.stringValue));
			addToken(tokens, newSpace());
		}
		
		// content
		build(node, tokens);
	}
	
	/**
	 * node is (class)
	 */
	private function buildClass(node:IParserNode, tokens:Vector.<Token>):void
	{
		state = AS3NodeKind.CLASS;
		// meta-list
		buildMetaList(node, tokens);
		// as-doc
		buildAsDoc(node, tokens);
		// modifiers
		buildModifiers(node, tokens);
		// class
		addToken(tokens, newClass());
		addToken(tokens, newSpace());
		// name
		var name:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, node);
		addToken(tokens, newToken(name.stringValue));
		addToken(tokens, newSpace());
		// extends
		var extendz:IParserNode = ASTUtil.getNode(AS3NodeKind.EXTENDS, node);
		if (extendz)
		{
			addToken(tokens, newToken(KeyWords.EXTENDS));
			addToken(tokens, newSpace());
			addToken(tokens, newToken(extendz.stringValue));
			addToken(tokens, newSpace());
		}
		// implements
		var impls:IParserNode = ASTUtil.getNode(AS3NodeKind.IMPLEMENTS_LIST, node);
		if (impls)
		{
			addToken(tokens, newToken(KeyWords.IMPLEMENTS));
			addToken(tokens, newSpace());
			var len:int = impls.numChildren;
			for (var i:int = 0; i < len; i++)
			{
				var impl:IParserNode = impls.children[i] as IParserNode;
				addToken(tokens, newToken(impl.stringValue));
				if (i < len - 1)
					addToken(tokens, newComma());
				addToken(tokens, newSpace());
			}
		}
		// content
		var content:IParserNode = ASTUtil.getNode(AS3NodeKind.CONTENT, node);
		build(content, tokens);
	}
	
	/**
	 * node is (interface)
	 */
	private function buildInterface(node:IParserNode, tokens:Vector.<Token>):void
	{
		state = AS3NodeKind.INTERFACE;
		
		// modifiers
		buildModifiers(node, tokens);
		// interface
		addToken(tokens, newInterface());
		addToken(tokens, newSpace());
		// name
		var name:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, node);
		addToken(tokens, newToken(name.stringValue));
		addToken(tokens, newSpace());
		// extends
		var extendz:Vector.<IParserNode> = ASTUtil.getNodes(AS3NodeKind.EXTENDS, node);
		if (extendz && extendz.length > 0)
		{
			addToken(tokens, newToken(KeyWords.EXTENDS));
			addToken(tokens, newSpace());
			var len:int = extendz.length;
			for (var i:int = 0; i < len; i++)
			{
				var extend:IParserNode = extendz[i] as IParserNode;
				addToken(tokens, newToken(extend.stringValue));
				if (i < len - 1)
					tokens.push(newComma());
				addToken(tokens, newSpace());
			}
		}
		// content
		var content:IParserNode = ASTUtil.getNode(AS3NodeKind.CONTENT, node);
		build(content, tokens);
	}
	
	/**
	 * node is (function)
	 */
	private function buildFunction(node:IParserNode, tokens:Vector.<Token>):void
	{
		// as-doc
		buildAsDoc(node, tokens);
		if (state == AS3NodeKind.CLASS)
		{
			// modifiers
			buildModifiers(node, tokens);
		}
		// function
		addToken(tokens, newToken(KeyWords.FUNCTION));
		addToken(tokens, newSpace());
		// name
		var name:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, node);
		addToken(tokens, newToken(name.stringValue));
		// parameters
		addToken(tokens, newLeftParenthesis());
		var parameterList:IParserNode = ASTUtil.getNode(AS3NodeKind.PARAMETER_LIST, node);
		if (parameterList)
		{
			var len:int = parameterList.numChildren;
			for (var i:int = 0; i < len; i++)
			{
				var param:IParserNode = parameterList.children[i] as IParserNode;
				var nti:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME_TYPE_INIT, param);
				var rest:IParserNode = ASTUtil.getNode(AS3NodeKind.REST, param);
				if (nti)
				{
					var nameNode:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, nti);
					var typeNode:IParserNode = ASTUtil.getNode(AS3NodeKind.TYPE, nti);
					var initNode:IParserNode = ASTUtil.getNode(AS3NodeKind.INIT, nti);
					if (nameNode)
					{
						addToken(tokens, newToken(nameNode.stringValue));
					}
					if (typeNode)
					{
						addToken(tokens, newColumn());
						addToken(tokens, newToken(typeNode.stringValue));
					}
					if (initNode)
					{
						var primary:IParserNode = initNode.getChild(0);
						addToken(tokens, newSpace());
						addToken(tokens, newEquals());
						addToken(tokens, newSpace());
						addToken(tokens, newToken(primary.stringValue));
					}
				}
				else if (rest)
				{
					addToken(tokens, newRestParameters());
					addToken(tokens, newToken(rest.stringValue));
				}
				
				if (i < len - 1)
				{
					addToken(tokens, newComma());
					addToken(tokens, newSpace());
				}
			}
		}
		addToken(tokens, newRightParenthesis());
		// returnType
		var returnType:IParserNode = ASTUtil.getNode(AS3NodeKind.TYPE, node);
		if (returnType)
		{
			addToken(tokens, newColumn());
			addToken(tokens, newToken(returnType.stringValue));
		}
		if (state == AS3NodeKind.CLASS)
		{
			addToken(tokens, newSpace());
			// block
			var block:IParserNode = ASTUtil.getNode(AS3NodeKind.BLOCK, node);
			build(block, tokens);
		}
		else
		{
			addToken(tokens, newSemiColumn());
		}
	}
	
	/**
	 * node is (class|interface|function)
	 */
	private function buildAsDoc(node:IParserNode, tokens:Vector.<Token>):void
	{
		var asdoc:IParserNode = ASTUtil.getNode(AS3NodeKind.AS_DOC, node);
		if (!asdoc)
			return;
		
		//var ast:IParserNode = ParserFactory.instance.asdocParser.
		//	buildAst(Vector.<String>(asdoc.stringValue.split("\n")), "internal");
		
		var ast:IParserNode = asdoc.getLastChild();
		
		var element:IParserNode;
		var content:IParserNode = ast.getChild(0);
		var shortList:IParserNode = ASTUtil.getNode(ASDocNodeKind.SHORT_LIST, content);
		var longList:IParserNode = ASTUtil.getNode(ASDocNodeKind.LONG_LIST, content);
		var doctagList:IParserNode = ASTUtil.getNode(ASDocNodeKind.DOCTAG_LIST, content);
		
		addToken(tokens, newToken("/**"));
		addToken(tokens, newNewLine());
		// do short-list
		if (shortList && shortList.numChildren > 0)
		{
			addToken(tokens, newToken(" * "));
			for each (element in shortList.children)
			{
				addToken(tokens, newToken(element.stringValue));
			}
			addToken(tokens, newNewLine());
		}
		// do long-list
		if (longList && longList.numChildren > 0)
		{
			addToken(tokens, newToken(" * "));
			addToken(tokens, newNewLine());
			addToken(tokens, newToken(" * "));
			for each (element in longList.children)
			{
				addToken(tokens, newToken(element.stringValue));
			}
			addToken(tokens, newNewLine());
		}
		// do doctag-list
		if (doctagList && doctagList.numChildren > 0)
		{
			if(shortList && shortList.numChildren > 0)
			{
				addToken(tokens, newToken(" * "));
				addToken(tokens, newNewLine());
			}
			
			addToken(tokens, newToken(" * "));
			var len:int = doctagList.numChildren;
			for (var i:int = 0; i < len; i++)
			{
				element = doctagList.children[i] as IParserNode;
				
				var name:IParserNode = element.getChild(0);
				addToken(tokens, newToken("@"));
				addToken(tokens, newToken(name.stringValue));
				addToken(tokens, newSpace());
				if (element.numChildren > 1)
				{
					var body:IParserNode = element.getChild(1);
					addToken(tokens, newToken(body.getLastChild().stringValue));
				}
				addToken(tokens, newNewLine());
				if (i < len - 1)
					addToken(tokens, newToken(" * "));
			}
		}
		addToken(tokens, newToken(" */"));
		addToken(tokens, newNewLine());
	}
	
	/**
	 * node is (class|interface|function)
	 */
	private function buildMetaList(node:IParserNode, tokens:Vector.<Token>):void
	{
		var metaList:IParserNode = ASTUtil.getNode(AS3NodeKind.META_LIST, node);
		if (!metaList || metaList.numChildren == 0)
			return;
		
		var len:int = metaList.numChildren;
		for (var i:int = 0; i < len; i++)
		{
			var child:IParserNode = metaList.children[i];
			var name:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, child);
			addToken(tokens, newLeftSquareBracket());
			addToken(tokens, newToken(name.stringValue));
			var paramList:IParserNode = ASTUtil.getNode(AS3NodeKind.PARAMETER_LIST, child);
			if (paramList && paramList.numChildren > 0)
			{
				addToken(tokens, newLeftParenthesis());
				var lenj:int = paramList.numChildren;
				for (var j:int = 0; j < lenj; j++)
				{
					var param:IParserNode = paramList.children[j];
					var pname:IParserNode = ASTUtil.getNode(AS3NodeKind.NAME, param);
					var pvalue:IParserNode = ASTUtil.getNode(AS3NodeKind.VALUE, param);
					if (pname)
					{
						addToken(tokens, newToken(pname.stringValue));
						addToken(tokens, newEquals());
					}
					if (pvalue)
					{
						addToken(tokens, newToken(pvalue.stringValue));
					}
					if (j < lenj - 1)
						addToken(tokens, newComma());
				}
				addToken(tokens, newRightParenthesis());
			}
			addToken(tokens, newRightSquareBracket());
			addToken(tokens, newNewLine());
		}
	}
	
	/**
	 * node is (class|interface|function)
	 */
	protected function buildModifiers(node:IParserNode, tokens:Vector.<Token>):void
	{
		var mods:IParserNode = ASTUtil.getNode(AS3NodeKind.MOD_LIST, node);
		if (mods)
		{
			for each (var mod:IParserNode in mods.children)
			{
				addToken(tokens, newToken(mod.stringValue));
				addToken(tokens, newSpace());
			}
		}
	}
	
	protected function buildContainerAfterStartNewline(node:IParserNode):Token
	{
		switch (node.kind)
		{
			case AS3NodeKind.CONTENT:
				lastToken = newNewLine();
				break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildContainerBeforeStartNewline(node:IParserNode):Token
	{
		switch (node.kind)
		{
			//case AS3NodeKind.CONTENT:
			//	lastToken = newNewLine();
			//	break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildContainerEndNewline(node:IParserNode):Token
	{
		switch (node.kind)
		{
			case AS3NodeKind.CONTENT:
				
				indent--;
				lastToken = newNewLine();
				break;
			
			case AS3NodeKind.BLOCK:
				
				indent--;
				lastToken = newNewLine();
				break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildStartSpace(node:IParserNode):Token
	{
		switch (node.kind)
		{
			case AS3NodeKind.NAME:
				lastToken = newSpace();
				break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildEndSpace(node:IParserNode):Token
	{
		switch (node.kind)
		{
			case AS3NodeKind.NAME:
				lastToken = newSpace();
				break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildContainerStart(container:IParserNode):Token
	{
		switch (container.kind)
		{
			case AS3NodeKind.PACKAGE:
				//lastToken = newPackage();
				//break;
				return null;
				
			case AS3NodeKind.CONTENT:
			{
				lastToken = newLeftCurlyBracket();
				indent++;
				break;
			}
				
			case AS3NodeKind.BLOCK:
			{
				lastToken = newLeftCurlyBracket();
				indent++;
				break;
			}
				
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildNode(node:IParserNode):Token
	{
		// TEMP fix for toplevel package being null
		var text:String = node.stringValue;
		if (text == null)
			text = "";
		
		switch (node.kind)
		{
			case AS3NodeKind.NAME:
				lastToken = newToken(text);
				break;
			
			case AS3NodeKind.MODIFIER:
				lastToken = newToken(text);
				break;
			
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function buildContainerEnd(container:IParserNode):Token
	{
		switch (container.kind)
		{
			case AS3NodeKind.PACKAGE:
				state = AS3NodeKind.COMPILATION_UNIT;
				return null;
				
			case AS3NodeKind.CONTENT:
			{
				lastToken = newRightCurlyBracket();
				break;
			}
				
			case AS3NodeKind.BLOCK:
			{
				lastToken = newRightCurlyBracket();
				break;
			}
				
			default:
				return null;
		}
		
		return lastToken;
	}
	
	protected function addToken(tokens:Vector.<Token>, token:Token):void
	{
		if (token)
		{
			tokens.push(token);
		}
		
		// start was correct
		if (token && token.text == "\n")
		{
			tokens.push(newLineIndent());
		}
	}
	
	protected function print(tokens:Vector.<Token>):String
	{
		var sb:String = "";
		
		for each (var element:Token in tokens) 
		{
			sb += element.text;
		}
		
		return sb;
	}
	
	public function newToken(text:String):Token
	{
		return Token.create(text, -1, -1);
	}
	
	// package
	public function newPackage():Token
	{
		return newToken(KeyWords.PACKAGE);
	}
	
	// class
	public function newClass():Token
	{
		return newToken(KeyWords.CLASS);
	}
	
	// interface
	public function newInterface():Token
	{
		return newToken(KeyWords.INTERFACE);
	}
	
	// {
	public function newLeftCurlyBracket():Token
	{
		return newToken(Operators.LEFT_CURLY_BRACKET);
	}
	
	// }
	public function newRightCurlyBracket():Token
	{
		return newToken(Operators.RIGHT_CURLY_BRACKET);
	}
	
	// "("
	public function newLeftParenthesis():Token
	{
		return newToken(Operators.LEFT_PARENTHESIS);
	}
	
	// ")"
	public function newRightParenthesis():Token
	{
		return newToken(Operators.RIGHT_PARENTHESIS);
	}
	
	// "["
	public function newLeftSquareBracket():Token
	{
		return newToken(Operators.LEFT_SQUARE_BRACKET);
	}
	
	// "]"
	public function newRightSquareBracket():Token
	{
		return newToken(Operators.RIGHT_SQUARE_BRACKET);
	}
	
	// "="
	public function newEquals():Token
	{
		return newToken("=");
	}
	
	// ","
	public function newComma():Token
	{
		return newToken(",");
	}
	
	// ";"
	public function newSemiColumn():Token
	{
		return newToken(Operators.SEMI_COLUMN);
	}
	
	// ":"
	public function newColumn():Token
	{
		return newToken(Operators.COLUMN);
	}
	
	// "..."
	public function newRestParameters():Token
	{
		return newToken(Operators.REST_PARAMETERS);
	}
	
	
	// " "
	public function newSpace():Token
	{
		return newToken(" ");
	}
	
	// "    "
	public function newIndent():Token
	{
		return newToken("\t");
	}
	
	// "    [i]"
	public function newLineIndent():Token
	{
		var sb:String = "";
		var len:int = indent;
		for (var i:int = 0; i < len; i++)
		{
			// TODO make this configurable
			sb += "    "; // newIndent()
		}
		
		return newToken(sb);
	}
	
	// "\n"
	public function newNewLine():Token
	{
		return newToken("\n");
	}
	
	/**
	 * @private
	 */
	private static var _instance:BuilderFactory;
	
	/**
	 * Returns the single instance of the BuilderFactory.
	 */
	public static function get instance():BuilderFactory
	{
		if (!_instance)
			_instance = new BuilderFactory();
		return _instance;
	}
}
}