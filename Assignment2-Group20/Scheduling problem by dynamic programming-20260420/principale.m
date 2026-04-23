clear;
clc;
J=[1 2 3 4]';
p= [8 6 10 7]';
d=[14 9 16 16]';

X0=0;
X1=combnk(1:4,1); 
X2=combnk(1:4,2); 
X3=combnk(1:4,3); 
X4=combnk(1:4,4);

%passo 4;
stati(4)=length(X4(:,1));
G4o=0;

%passo 3;
stati(3)=length(X3(:,1));
G3=10000*ones(stati(3),stati(4));
for i=1:stati(3)
    start_time=durata(X3(i,:),p);
    for j=1:stati(4)
        if ismember(X3(i,:),X4(j,:))
        controllo(i,j)=setdiff(X4(j,:),X3(i,:));
        G3(i,j)=G4o(j)+...
        max((start_time+...
        p(controllo(i,j))-d(controllo(i,j)))/4, 0);
         end
    end
    G3o(i)=min(G3(i,:));
end

%passo 2;
stati(2)=length(X2(:,1));
G2=10000*ones(stati(2),stati(3));
for i=1:stati(2)
    start_time=durata(X2(i,:),p);
    for j=1:stati(3)
        if ismember(X2(i,:),X3(j,:))
        controllo(i,j)=setdiff(X3(j,:),X2(i,:));
        G2(i,j)=G3o(j)+...
        max((start_time+...
        p(controllo(i,j))-d(controllo(i,j)))/4, 0);
         end
    end
    G2o(i)=min(G2(i,:));
end

%passo 1;
stati(1)=length(X1(:,1));
G1=10000*ones(stati(1),stati(2));
for i=1:stati(1)
    start_time=durata(X1(i,:),p);
    for j=1:stati(2)
        if ismember(X1(i,:),X2(j,:))
        controllo(i,j)=setdiff(X2(j,:),X1(i,:));
        G1(i,j)=G2o(j)+...
        max((start_time+...
        p(controllo(i,j))-d(controllo(i,j)))/4, 0);
         end
    end
    G1o(i)=min(G1(i,:));
end

%passo 0;
for i=1:length(J)
         G0(i)=G1o(i)+...
        max((p(X1(i))-d(X1(i)))/4, 0);
end
G0o=min(G0);