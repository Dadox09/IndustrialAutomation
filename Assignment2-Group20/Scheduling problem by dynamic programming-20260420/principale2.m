clear;
clc;
J=[1 2 3 4]';
p= [8 6 10 7]';
d=[14 9 16 16]';
X0=0;
X{1}=combnk(1:4,1); 
X{2}=combnk(1:4,2); 
X{3}=combnk(1:4,3); 
X{4}=combnk(1:4,4);

%passo 4;
stati(4)=length(X{4}(:,1));
Go{4}=0;

%passo k=3-2-1;
for k=3:-1:1
    stati(k)=length(X{k}(:,1));
G{k}=10000*ones(stati(k),stati(k+1));
for i=1:stati(k)
    start_time=sum(p(X{k}(i,:)));
    for j=1:stati(k+1)
        if ismember(X{k}(i,:),X{k+1}(j,:))
        controllo(i,j)=setdiff(X{k+1}(j,:),X{k}(i,:));
        G{k}(i,j)=Go{k+1}(j)+...
        max((start_time+...
        p(controllo(i,j))-d(controllo(i,j)))/4, 0);
         end
    end
    Go{k}(i)=min(G{k}(i,:));
end
end

%passo 0;
for i=1:length(J)
         G0(i)=Go{1}(i)+...
        max((p(X{1}(i))-d(X{1}(i)))/4, 0);
end
Go0=min(G0);