clear
clc
%6 jobs 
%parameters
dd=[15 6 9 23 20 30]';
p=[10 3 4 8 10 6]';
%solve the problem 6/1//nt by mathematical programming

%define a optimproblem "object"
prob=optimproblem('ObjectiveSense','min');

%%
%definition of the decisional variables (optimivar)
%starting time for each job
s=optimvar('s',6,1,'LowerBound',0);
%completion time for each job
c=optimvar('c',6,1,'LowerBound',0);
%number of jobs that are late
nT=optimvar('nT',1,1);
%late(j) =1 if job j is late 0 otherwise
late=optimvar('late',6,1,...
    'Type','integer','LowerBound',0,'UpperBound',1);
%x(i,j) 1 if job i is before job j; 0 otherwise
x=optimvar('x',6,6,...
    'Type','integer','LowerBound',0,'UpperBound',1);
%%
%mathematical problem definition
%cost function
objective=nT;
prob.Objective=objective;
%constraints
%constraints 1 related to set of x for all (i,j) but
%i~j
cons1 = optimconstr(36-6);
count=0;
for i=1:6
    for j=1:6
    count=count+1;
    if (i~=j)
    cons1(count)=s(j,1)>=c(i,1)-10000*(1-x(i,j));
    end
    end
end
prob.Constraints.cons1=cons1;

%constraints 2 related to set of x for all (i,j) but
%i~j
cons2 = optimconstr(36-6);
count=0;
for i=1:6
    for j=1:6
    count=count+1;
    if (i~=j)
    cons2(count)=s(i,1)>=c(j,1)-10000*(x(i,j));
    end
    end
end
prob.Constraints.cons2=cons2;

%constraint 3 definition of late variable
cons3 = optimconstr(6);
for i=1:6
    cons3(i)=(c(i,1)-dd(i,1))-10000*late(i,1)<=0;
end
prob.Constraints.cons3=cons3;

%constraint 4
%definition of total jobs that are late nT
cons4(i)=nT==sum(late);
prob.Constraints.cons4=cons4;

%constraint 5
%definition of total jobs that are late nT
cons5 = optimconstr(6);
for i=1:6
    cons5(i)=c(i,1)==s(i,1)+p(i,1);
end
prob.Constraints.cons5=cons5;

%solve the problem
[xopt, val]=solve(prob);
