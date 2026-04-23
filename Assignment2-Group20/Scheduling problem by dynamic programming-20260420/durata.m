function len=durata(J,p)
temp=0;
for i=1:length(J)
temp=temp+p(J(i));
end
len=temp;
end