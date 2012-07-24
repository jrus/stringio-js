###
File-like objects that read from or write to a string buffer.

A nearly direct port of Python’s StringIO module.

f = StringIO()       # ready for writing
f = StringIO(buf)    # ready for reading
f.close()            # explicitly release resources held
pos = f.tell()       # get current position
f.seek(pos)          # set current position
f.seek(pos, mode)    # mode 0: absolute; 1: relative; 2: relative to EOF
buf = f.read()       # read until EOF
buf = f.read(n)      # read up to n bytes
buf = f.readline()   # read until end of line ('\n') or EOF
list = f.readlines() # list of f.readline() results until EOF
f.truncate([size])   # truncate file to at most size (default: current pos)
f.write(buf)         # write at current position
f.writelines(list)   # for line in list: f.write(line)
f.getvalue()         # return whole file's contents as a string

Notes:
- Seeking far beyond EOF and then writing will insert real null
  bytes that occupy space in the buffer.
- There's a simple test set (see end of this file).
###


_complain_ifclosed = (closed) ->
    if closed then throw new Error 'I/O operation on closed file'


### class StringIO([buffer])

When a StringIO object is created, it can be initialized to an existing
string by passing the string to the constructor. If no string is given,
the StringIO will start empty. ###
class StringIO
    constructor: (buf='') ->
        @buf = '' + buf
        @length = @buf.length
        @buflist = []
        @pos = 0
        @closed = false    

    ### Free the memory buffer. ###
    close: ->
        if not @closed
            @closed = true
            delete @buf
            delete @pos
        return

    _flush_buflist: ->
        @buf += @buflist.join ''
        @buflist = []

    ### Set the file's current position.

    The mode argument is optional and defaults to 0 (absolute file
    positioning); other values are 1 (seek relative to the current
    position) and 2 (seek relative to the file's end).

    There is no return value. ###
    seek: (pos, mode=0) ->
        _complain_ifclosed @closed
        @_flush_buflist() if @buflist.length
        if mode == 1
            pos += @pos
        else if mode == 2
            pos += @length
        @pos = Math.max 0, pos
        return

    ### Return the file's current position. ###
    tell: ->
        _complain_ifclosed @closed
        @pos

    ### Read at most size bytes from the file
    (less if the read hits EOF before obtaining size bytes).

    If the size argument is negative or omitted, read all data until EOF
    is reached. The bytes are returned as a string object. An empty
    string is returned when EOF is encountered immediately. ###
    read: (n=-1) ->
        _complain_ifclosed @closed
        @_flush_buflist() if @buflist.length
        if n < 0
            newpos = @length
        else
            newpos = Math.min @pos + n, @length
        r = @buf.slice @pos, newpos
        @pos = newpos
        r

    ### Read one entire line from the file.
    
    A trailing newline character is kept in the string (but may be absent
    when a file ends with an incomplete line). If the size argument is
    present and non-negative, it is a maximum byte count (including the
    trailing newline) and an incomplete line may be returned.

    An empty string is returned only when EOF is encountered immediately. ###
    readline: (length=null) ->
        _complain_ifclosed @closed
        @_flush_buflist() if @buflist.length
        i = @buf.indexOf '\n', @pos
        if i < 0
            newpos = @length
        else
            newpos = i + 1
        if length? and @pos + length < newpos
            newpos = @pos + length
        r = @buf.slice @pos, newpos
        @pos = newpos
        r

    ### Read until EOF using readline() and return a list containing the
    lines thus read.

    If the optional sizehint argument is present, instead of reading up
    to EOF, whole lines totalling approximately sizehint bytes (or more
    to accommodate a final whole line). ###
    readlines: (sizehint=0) ->
        total = 0
        lines = []
        line = @readline()
        while line
            lines.push line
            total += line.length
            break if 0 < sizehint <= total
            line = @readline()
        lines

    ### Truncate the file's size.

    If the optional size argument is present, the file is truncated to
    (at most) that size. The size defaults to the current position.
    The current file position is not changed unless the position
    is beyond the new file size.

    If the specified size exceeds the file's current size, the
    file remains unchanged. ###
    truncate: (size=null) ->
        _complain_ifclosed @closed
        if not size?
            size = @pos
        else if size < 0
            throw new Error 'Negative size not allowed'
        else if size < @pos
            @pos = size
        @buf = @getvalue().slice 0, size
        @length = size
        return

    ### Write a string to the file.

    There is no return value. ###
    write: (s) ->
        _complain_ifclosed @closed
        return unless s
        # Force s to be a string
        unless typeof s == 'string'
            s = s.toString()
        spos = @pos
        slen = @length
        if spos == slen
            @buflist.push s
            @length = @pos = spos + s.length
            return
        if spos > slen
            null_bytes = (Array spos - slen + 1).join '\x00'
            @buflist.push null_bytes
            slen = spos
        newpos = spos + s.length
        if spos < slen
            @_flush_buflist() if @buflist.length
            @buflist.push (@buf.slice 0, spos), s, (@buf.slice newpos)
            @buf = ''
            if newpos > slen
                slen = newpos
        else
            @buflist.push s
            slen = newpos
        @length = slen
        @pos = newpos
        return

    ### Write a sequence of strings to the file. The sequence can be any
    iterable object producing strings, typically a list of strings. There
    is no return value.

    (The name is intended to match readlines(); writelines() does not add
    line separators.) ###
    writelines: (array) -> 
        (@write line) for line in array
        return

    ### Flush the internal buffer ###
    flush: ->
        _complain_ifclosed @closed
        return  # basically a no-op

    ### Retrieve the entire contents of the "file" at any time
    before the StringIO object's close() method is called. ###
    getvalue: ->
        @_flush_buflist() if @buflist.length
        @buf


module_root =
    if exports? then exports
    else if window? then window
    else this
module_root.StringIO = StringIO


# A little test suite
_test = ->
    print = -> console.log arguments...
    lines = [
        'This is a test,\n'
        'Blah blah blah,\n'
        'Wow does this work?\n'
        'Okay, here are some lines\n'
        'of text.\n'
        ]
    f = new StringIO
    for line in lines.slice 0, -2
        f.write line
    f.writelines lines.slice -2
    if f.getvalue() != lines.join ''
        throw new Error 'write failed'
    length = f.tell()
    print 'File length =', length
    f.seek lines[0].length
    f.write lines[1]
    f.seek 0
    print "First line = #{f.readline()}"
    print "Position = #{f.tell()}"
    line = f.readline()
    print "Second line = #{line}"
    f.seek -line.length, 1
    line2 = f.read line.length
    if line != line2
        throw new Error 'bad result after seek back'
    f.seek -line2.length, 1
    list = f.readlines()
    line = list[list.length - 1]
    f.seek f.tell() - line.length
    line2 = f.read()
    if line != line2
        throw new Error 'bad result after seek back from EOF'
    print "Read #{list.length} more lines"
    print "File length = #{f.tell()}"
    if f.tell() != length
        throw new Error 'bad length'
    f.truncate (length / 2) | 0
    f.seek 0, 2
    print "Truncated length = #{f.tell()}"
    if f.tell() != ((length / 2) | 0)
        throw new Error 'truncate did not adjust length'
    f.close()
