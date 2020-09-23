<div align="center">

## FYI: GDI\+ Crash in IDE


</div>

### Description

Generic thunk class added. Using it will negate crash described below and can be used to start GDI+... GDI+ when not shut down properly can crash IDE (maybe XP only. See comments below on test results). For those of you that use unsafe subclassing while in IDE, this effect is very familiar. Read the article below and to test a crash, you can run the zipped project. I, and others, can replicate the crash every time on XP Pro. May be a DLL version issue, may be something else.
 
### More Info
 


<span>             |<span>
---                |---
**Submitted On**   |2007-10-06 17:32:26
**By**             |[LaVolpe](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByAuthor/lavolpe.md)
**Level**          |Beginner
**User Rating**    |5.0 (15 globes from 3 users)
**Compatibility**  |VB 5\.0, VB 6\.0
**Category**       |[Debugging and Error Handling](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByCategory/debugging-and-error-handling__1-26.md)
**World**          |[Visual Basic](https://github.com/Planet-Source-Code/PSCIndex/blob/master/ByWorld/visual-basic.md)
**Archive File**   |[FYI\_\_GDI\+\_2086191062007\.zip](https://github.com/Planet-Source-Code/lavolpe-fyi-gdi-crash-in-ide__1-69434/archive/master.zip)





### Source Code

GDI+ is an excellent tool for custom drawing and allowing VB to use PNGs, TIFFs, and other file formats. However, if it is not shut down, you can crash your app. XP-related and possibly Vista?
<br><br>
Uncompiled usercontrol (uc) problems.<br>
 1. Your uc creates GDI+ token for life of uc<br>
 2. In your uc's Terminate event, you shutdown GDI+<br>
 3. You run your app and hit END because of a Debug error or simply hit the VB toolbar's Stop button<br>
 4. A crash occurs shortly thereafter, maybe 2 minutes later, maybe 10 minutes later & you lost any updated/unsaved code you had.<br> This isn't a problem when uc is compiled because a compiled uc gets a terminate event even if it is added to an uncompiled project.<br>
 5. Why the crash? Because END prevents firing any uncompiled object's Terminate event and therefore, GDI+ isn't shut down because it gets triggered in the terminate event.
<br><br>
When in IDE:<br>
To prevent GDI+ crashing. You have 2 choices<br>
1. Create token, use GDI+, destroy token immediately<br>
2. Never hit END or use VB's toolbar STOP button. And if you do. Save your project immediately. Close VB and re-open project.<br>
Though a crash is probably imminent, at least you have some time to save your work<br>
<br><br>
I experienced this recently with my AlphaImage control and troubleshooting led me to post this article.

