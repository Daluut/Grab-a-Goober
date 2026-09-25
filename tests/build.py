import re
import os
R=os.path.join(os.path.dirname(os.path.abspath(__file__)), '..') + '/'
def lit(path):
    s=open(path).read().replace('\r\n','\n')
    n=0
    while ('='*n+']') in s: n+=1
    eq='='*(n+1)
    return '['+eq+'['+s+']'+eq+']'
run=open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'run.luau')).read()
run=re.sub(r'local function readfile\(p\)\n.*?\nend\n','',run,flags=re.S)
out='SRC_MOCK = '+lit(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'mock.luau'))+'\nSRC_CONFIG = '+lit(R+'1_Config_ModuleScript.lua')+'\nSRC_CREATURES = '+lit(R+'4_Creatures_ModuleScript.lua')+'\nSRC_SERVER = '+lit(R+'2_GameServer_Script.lua')+'\n'+run
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'all.luau'),'w').write(out)
