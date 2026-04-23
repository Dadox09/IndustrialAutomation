clear
clc
%2 machines index k
%7 jobs 
%parameters
p=[6 2 4 1 7 4 7
   3 9 3 8 1 5 6];
%solve the problem 7/2//Cmax by mathematical programming

%define a optimproblem "object"
prob=optimproblem('ObjectiveSense','min');

%%
%definition of the decisional variables (optimivar)
%max completion time
Cmax=optimvar('Cmax',1,1);
%starting time for each job
s=optimvar('s',2,7,'LowerBound',0);
%completion time for each job
c=optimvar('c',2,7,'LowerBound',0);
%x(k, i,j) 1 on machine k if job i is before job j; 0 otherwise
x=optimvar('x',2,7,7,...
    'Type','integer','LowerBound',0,'UpperBound',1);
%%
%mathematical problem definition
%cost function
objective=Cmax;
prob.Objective=objective;
%constraints
%constraint 5
%definition of ccompletion time
cons1 = optimconstr(2*7);
count=0;
for k=1:2
for i=1:7
    count=count+1;
    cons1(count)=c(k,i)==s(k,i)+p(k,i);
end
prob.Constraints.cons1=cons1;
end

%constraints 2 related to set of x for all (i,j) but
%i~j
cons2 = optimconstr(2*(7*7-7));
count=0;
for k=1:2
    for i=1:7
    for j=1:7
    count=count+1;
    if (i~=j)
    cons2(count)=s(k,j)>=c(k,i)-10000*(1-x(k,i,j));
    end
    end
end
end
prob.Constraints.cons2=cons2;

%constraints 2 related to set of x for all (i,j) but
%i~j
cons3 = optimconstr(2*(7*7-7));
count=0;
for k=1:2
    for i=1:7
    for j=1:7
    count=count+1;
    if (i~=j)
    cons3(count)=s(k,i)>=c(k,j)-10000*(x(k,i,j));
    end
    end
end
end
prob.Constraints.cons3=cons3;

%constraint 4
%definition of total jobs that are late nT
cons4 = optimconstr(7);
for i=1:7
cons4(i)=Cmax>=c(2,i);
end
prob.Constraints.cons4=cons4;

%constraint 5
%definition of total jobs that are late nT
cons5 = optimconstr(7);
for i=1:7
cons5(i)=s(2,i)>=c(1,i);
end
prob.Constraints.cons5=cons5;

%solve the problem
[xopt, val]=solve(prob);
