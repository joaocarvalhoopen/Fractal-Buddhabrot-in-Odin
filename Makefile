all:
	odin build . -out:fratal_buddhabrot.exe

opti:
	odin build . -out:fratal_buddhabrot.exe -o:speed

clean:
	rm fratal_buddhabrot.exe

run:
	./fratal_buddhabrot.exe
