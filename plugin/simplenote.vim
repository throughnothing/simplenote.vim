"
"
" File: simplenote.vim
" Author: Daniel Schauenberg <d@unwiredcouch.com>
" WebPage: http://github.com/mrtazz/simplenote.vim
" License: MIT
" Usage:
"
"
"

if &cp || (exists('g:loaded_simplenote_vim') && g:loaded_simplenote_vim)
  finish
endif
let g:loaded_simplenote_vim = 1

" check for python
if !has("python")
  echoerr "Simplenote: Plugin needs vim to be compiled with python support."
  finish
endif

" user auth settings
let s:token = ""
try
  silent let s:user = g:SimpleNoteUserName
catch
  let s:user = ""
endtry
try
  silent let s:password = g:SimpleNotePassword
catch 
  let s:password = ""
endtry


"
" Helper functions
"
function! s:SimpleNoteGetAuth()
  if(s:user == "")
    let s:user = input("SimpleNote Username: ")  
  endif
  if(s:password == "")
    let s:password = inputsecret("SimpleNote Password: ")  
  endif
endfunction

"
" API functions
"

"
" @brief function to get simplenote auth token
"
" @param user -> simplenote email address
" @param password -> simplenote password
"
" @return simplenote API token
"
function! s:SimpleNoteAuth()
  call s:SimpleNoteGetAuth()
python << ENDPYTHON
import vim, urllib2, base64
url = 'https://simple-note.appspot.com/api/login'
# params parsing
user = vim.eval("s:user")
password = vim.eval("s:password")
auth_params = "email=%s&password=%s" % (user, password)
values = base64.encodestring(auth_params)
request = urllib2.Request(url, values)
try:
  token = urllib2.urlopen(request).read()
except IOError, e: # no connection exception
  print user
  print password
  #vim.command('echoerr "Simplenote: Auth failed."')
  #vim.command("return -1")

vim.command('return "%s"' % token)
ENDPYTHON
endfunction

"
" @brief function to get a specific note
"
" @param user -> simplenote username
" @param token -> simplenote API token
" @param noteid -> ID of the note to get
"
" @return content of the desired note
"
function! s:GetNote(noteid)
python << ENDPYTHON
import vim, urllib2, json
# params
user = vim.eval("s:user")
token = vim.eval("s:token")
noteid = vim.eval("a:noteid")
# request note
url = 'https://simple-note.appspot.com/api2/data/'
params = '%s?auth=%s&email=%s' % (noteid, token, user)
request = urllib2.Request(url+params)
try:
    response = urllib2.urlopen(request)
except IOError, e:
    vim.command('echoerr "Connection failed."')
    response = ""
note = json.loads(response.read())
vim.command("return %s" % note["content"])
ENDPYTHON
endfunction

"
" @brief function to update a specific note
"
" @param user -> simplenote username
" @param token -> simplenote API token
" @param noteid -> noteid to update
" @param content -> content of the note to update
"
" @return
"
function! s:UpdateNote(noteid, content)
python << ENDPYTHON
import vim, urllib,  urllib2, json
#params
user = vim.eval("s:user")
token = vim.eval("s:token")
noteid = vim.eval("a:noteid")
content = vim.eval("a:content")

url = 'https://simple-note.appspot.com/api2/data/'
params = '%s?auth=%s&email=%s' % (noteid, token, user)
noteobject = {}
noteobject["content"] = content
note = json.dumps(noteobject)
values = urllib.urlencode(note)
request = urllib2.Request(url+params, values)
try:
    response = urllib2.urlopen(request)
except IOError, e:
    vim.command('echoerr "Connection failed."')
ENDPYTHON
endfunction

"
" @brief function to get the note list
"
" @param user -> simplenote username
" @param token -> simplenote API token
"
" @return list of note titles
"
function! s:GetNoteList()
python << ENDPYTHON
import vim, json, urllib2
# params
user = vim.eval("s:user")
token = vim.eval("s:token")
url = 'https://simple-note.appspot.com/api2/index?'
params = 'auth=%s&email=%s' % (token, user)
request = urllib2.Request(url+params)
try:
  response = json.loads(urllib2.urlopen(request).read())
except IOError, e:
  response = { "data" : [] }
ret = []
# parse data fields in response
for d in response["data"]:
    ret.append(d["key"])

vim.command('return "%s"' % ret)
ENDPYTHON
endfunction

"
" User interface
"

function! s:SimpleNote(line1, line2, ...)
  if(s:token == "")
    let s:token = s:SimpleNoteAuth()
  endif

  let listnotes = 0
  let args = (a:0 > 0) ? split(a:1, ' ') : []
  for arg in args
    if arg =~ '^\(-l\|--list\)$'
      let listnotes = 1
    elseif arg =~ '^\(-u\|--update\)$'
      let updatenote = 1
    elseif len(arg) > 0
      echoerr 'Invalid arguments'
      unlet args
      return 0
    endif
  endfor
  unlet args
  if listnotes == 1
    let notes = s:GetNoteList()
    let winnum = bufwinnr(bufnr('notes:'.s:user))
    if winnum != -1
      if winnum != bufwinnr('%')
        exe "normal \<c-w>".winnum."w"
      endif
      setlocal modifiable
    else
      exec 'silent split notes:'.s:user
    endif
  endif

endfunction


" set the simplenote command
command! -nargs=? -range=% SimpleNote :call <SID>SimpleNote(<line1>, <line2>, <f-args>)
" vim:set et:
