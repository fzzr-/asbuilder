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

package org.as3commons.asbuilder.impl
{

import flash.events.Event;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.utils.Timer;

import org.as3commons.asblocks.ASBlocksSyntaxError;
import org.as3commons.asblocks.ASFactory;
import org.as3commons.asblocks.IASParser;
import org.as3commons.asblocks.api.IClassPathEntry;
import org.as3commons.asblocks.api.ICompilationUnit;
import org.as3commons.asblocks.impl.ASProject;
import org.as3commons.asblocks.impl.IParserInfo;
import org.as3commons.asblocks.parser.core.SourceCode;
import org.as3commons.asblocks.utils.FileUtil;
import org.as3commons.mxmlblocks.IMXMLParser;

/**
 * An Adobe AIR implementation of the <code>IASProject</code> API.
 * 
 * @author Michael Schmalle
 * @copyright Teoti Graphix, LLC
 * @productversion 1.0
 */
public class ASBuilderProject extends ASProject
{
	//--------------------------------------------------------------------------
	//
	//  Private :: Variables
	//
	//--------------------------------------------------------------------------
	
	private static const AS_EXT:String = "as";
	
	private static const MXML_EXT:String = "mxml";
	
	private var infos:Vector.<IParserInfo>;
	
	private var failedInfos:Vector.<IParserInfo>;
	
	private var asyncTimer:Timer;
	
	private var parseTimer:Timer;
	
	private var count:int;
	
	private var total:int;
	
	private var parseDelay:int = 50;
	
	//--------------------------------------------------------------------------
	//
	//  Constructor
	//
	//--------------------------------------------------------------------------
	
	/**
	 * Constructor.
	 */
	public function ASBuilderProject(factory:ASFactory)
	{
		super(factory);
	}
	
	//--------------------------------------------------------------------------
	//
	//  Overridden Protected :: Methods
	//
	//--------------------------------------------------------------------------
	
	/**
	 * @private
	 */
	override protected function write(location:String, unit:ICompilationUnit):void
	{
		var fileName:String = FileUtil.fileNameFor(unit);
		if (location == ".")
		{
			location = File.applicationStorageDirectory.nativePath;
		}
		
		var file:File = new File(location);
		file = file.resolvePath(fileName);
		
		var stream:FileStream = new FileStream();
		stream.open(file, FileMode.WRITE);
		
		var code:SourceCode = new SourceCode(null, file.nativePath);
		factory.newWriter().write(code, unit);
		stream.writeUTFBytes(code.code);
		stream.close();
	}
	
	/**
	 * @private
	 */
	override public function readAll():void
	{
		var asparser:IASParser = factory.newParser();
		var mxmlparser:IMXMLParser = factory.newMXMLParser();
		
		var files:Array = [];
		
		infos = new Vector.<IParserInfo>();
		failedInfos = new Vector.<IParserInfo>();
		
		for each (var entry:IClassPathEntry in classPathEntries)
		{
			readFiles(new File(entry.filePath), files);
			
			for each (var file:File in files)
			{
				var info:IParserInfo;
				var unit:ICompilationUnit;
				
				var sourceCode:SourceCode = new SourceCode(
					FileUtil.readFile(file.nativePath), file.nativePath);
				
				if (file.extension == "as")
				{
					info = asparser.parseAsync(sourceCode, entry, true);
				}
				else if (file.extension == "mxml")
				{
					info = mxmlparser.parseAsync(sourceCode, entry);
				}
				
				try
				{
					unit = info.parse();
					addCompilationUnit(unit);
				}
				catch (e:ASBlocksSyntaxError)
				{
					info.error = e;
					failedInfos.push(info);
				}
			}
		}
	}
	
	/**
	 * @private
	 */
	override public function readAllAsync():void
	{
		asyncTimer = new Timer(10, 1);
		asyncTimer.addEventListener(
			TimerEvent.TIMER_COMPLETE, 
			asyncTimer_timerCompleteHandler);
		
		var asparser:IASParser = factory.newParser();
		var mxmlparser:IMXMLParser = factory.newMXMLParser();
		
		var files:Array = [];
		infos = new Vector.<IParserInfo>();
		failedInfos = new Vector.<IParserInfo>();
		
		for each (var entry:IClassPathEntry in classPathEntries)
		{
			readFiles(new File(entry.filePath), files);
			
			for each (var file:File in files)
			{
				var sourceCode:SourceCode = new SourceCode(
					FileUtil.readFile(file.nativePath), file.nativePath);
				if (file.extension == AS_EXT)
				{
					infos.push(asparser.parseAsync(sourceCode, entry, true));
				}
				else if (file.extension == MXML_EXT)
				{
					infos.push(mxmlparser.parseAsync(sourceCode, entry));
				}
			}
		}
		
		count = total = infos.length;
		
		asyncTimer.start();
	}
	
	/**
	 * @private
	 */
	protected function readFiles(directory:File, result:Array = null):Array
	{
		if (result == null)
			result = [];
		
		var directories:Array = directory.getDirectoryListing();
		for each (var file:File in directories)
		{
			if (file.isDirectory)
			{
				result = readFiles(file, result);
			}
			else if (file.extension == AS_EXT || file.extension == MXML_EXT)
			{
				result.push(file);
			}
		}
		
		return result;
	}
	
	/**
	 * @private
	 */
	private function readNextAsync(event:Event = null):void
	{
		if (parseTimer)
		{
			parseTimer.removeEventListener(
				TimerEvent.TIMER_COMPLETE, 
				readNextAsync);
		}
		
		//trace("Files to parse [" + infos.length + "]");
		
		var info:IParserInfo = infos.shift();
		if (!info)
		{
			dispatchEvent(new ASBuilderProjectEvent(
				ASBuilderProjectEvent.PARSE_COMPLETE, 
				total, total));
			return;
		}
		
		dispatchEvent(new ASBuilderProjectEvent(
			ASBuilderProjectEvent.PARSE_PROGRESS, 
			count, total));
		
		//trace("Parsing [" + info.sourceCode.filePath + "]");
		
		var unit:ICompilationUnit;
		
		try
		{
			unit = info.parse();
			addCompilationUnit(unit);
		}
		catch (e:ASBlocksSyntaxError)
		{
			info.error = e;
			failedInfos.push(info);
		}
		
		count--;
		
		parseTimer = new Timer(parseDelay, 1);
		parseTimer.addEventListener(
			TimerEvent.TIMER_COMPLETE, 
			readNextAsync);
		parseTimer.start();
	}
	
	/**
	 * @private
	 */
	private function asyncTimer_timerCompleteHandler(event:TimerEvent):void
	{
		asyncTimer.removeEventListener(
			TimerEvent.TIMER_COMPLETE, asyncTimer_timerCompleteHandler);
		readNextAsync();
	}
}
}