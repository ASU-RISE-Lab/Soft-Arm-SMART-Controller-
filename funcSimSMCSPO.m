function par_set=funcSimSMCSPO(par_set,flag_input_bound)
%%%%%% Import data
testData=par_set.trial1;
%%%%%%

%%%%%% State Ini.
Ts=0.01; % sampling period
timeArray=[0:Ts:60]';%sec
x1=zeros(length(timeArray),1); %state variable theta
x2=zeros(length(timeArray),1); %state variable dtheta
dx1=zeros(length(timeArray),1); % time derivative of x1
dx2=zeros(length(timeArray),1); % time derivative of x2
%%% State Observer
x1_hat=zeros(length(timeArray),1); % state observer
x2_hat=zeros(length(timeArray),1); % state observer
x3_hat=zeros(length(timeArray),1); % state observer
dx1_hat=zeros(length(timeArray),1); % state observer
dx2_hat=zeros(length(timeArray),1); % state observer
dx3_hat=zeros(length(timeArray),1); % state observer
%%%
%%% Perterbation Observer
per_ob_hat=zeros(length(timeArray),1);
per_ob=zeros(length(timeArray),1);
x1_e=zeros(length(timeArray),1); % error of the estimation x1_hat-x1_d
x2_e=zeros(length(timeArray),1); % error of the estimation x2_hat-x2_d
s_hat=zeros(length(timeArray),1);
%%%
%%% Output Bound
pd1_upperlimit_MPa=40*0.00689476;
pd1_lowerlimit_MPa=1*0.00689476;
pm2_MPa=1*0.00689476;
pm3_MPa=1*0.00689476;
u_raw=zeros(length(timeArray),1); %unbounded input
u_bound=zeros(length(timeArray),1);   %bounded input

%%%
%%%%%%

%%%%%% System parameters
%%% Geometric
m0=0.35;     % segment weight kg
g=9.8;       % gravity
L=par_set.L;      % segment length
%%%
%%% Parameter Uncertainty
r0=mean(testData.beta);
phi=mean(testData.phi_rad);
alpha=par_set.meanAlpha;
k=par_set.meanK;
b=par_set.meanB;
Km=par_set.maxK-k;
Dm= par_set.maxB-b;
Alpham= (par_set.maxAlpha-alpha);
%%%
%%% Randomize the Delta K and D
deltaD=0;
deltaK=0;
seed1=rng;
Kmax = Km;
Kmin= -Km;
deltaK = (Kmax-Kmin).*rand(1,1) + Kmin;

seed2=rng;
Dmax =Dm;
Dmin= -Dm;
deltaD = (Dmax-Dmin).*rand(1,1) + Dmin;
deltaD=Dmax;
deltaK=Kmax;

seed3=rng;
Alphamax =Alpham;
Alphamin= -Alpham;
deltaAlpha = (Alphamax-Alphamin).*rand(1,1) + Alphamin;
%%%
%%% Max uncertainty
% deltaD=Dmax;
% deltaK=Kmax;
% deltaAlpha=Alphamax;
%%%
%%%%%%
%%%%%% Input reference
Amp=deg2rad(10);
Boff=deg2rad(-40);
freq=0.1;%Hz
xd=-Amp*sin(2*pi*freq*timeArray)+Boff;
dxd=-Amp*(2*pi*freq)*cos(2*pi*freq*timeArray);
ddxd=Amp*(2*pi*freq)^2*sin(2*pi*freq*timeArray);
%%%%%%
%% SMCSPO design parameter
smc_lambda_d=1/(15*0.1);
smc_epsil=1;
smc_k1_epsil=3*smc_lambda_d;
smc_k2_epsil=smc_lambda_d;
smc_alpha_3=sqrt(smc_lambda_d/3);
smc_c=smc_lambda_d;
smc_eta=smc_lambda_d*smc_epsil;
%%
% smc_epsil=0.1;
% smc_k1=
% smc_k2=abs(Kmax*deg2rad(90))+abs(Alphamax*0.1805)
%%
u_bar=zeros(length(timeArray),1); %unbounded input
disturb=zeros(length(timeArray),1);
%%
x1(1)=testData.theta_rad(1);
x1_hat(1)=x1(1);
for i=1:length(timeArray)-1
    %% SMCSPO
    x1_e(i,1)=x1_hat(i,1)-xd(i,1);
    x2_e(i,1)=x2_hat(i,1)-dxd(i,1);
    per_ob_hat(i,1)=smc_alpha_3*(-x3_hat(i,1)+smc_alpha_3*x2_hat(i,1));
    s_hat(i,1)=x2_hat(i,1)-smc_k1_epsil*x1_e(i,1)-dxd(i,1)+smc_c*x1_e(i,1);
    % Saturation function of sat(s_hat)
    if s_hat(i,1)>smc_epsil
        sat_s_hat=s_hat(i,1)/abs(s_hat(i,1));
    else
        sat_s_hat=s_hat(i,1)/smc_epsil;
    end
    u_bar(i,1)=1/smc_alpha_3*...
        (-smc_eta*sat_s_hat + ...
        (smc_k2_epsil + smc_c * smc_k1_epsil - smc_k1_epsil^2)*x1_e(i,1)+...
        ddxd(i,1)-smc_c*(x2_e(i,1)-dxd(i,1))-...
        per_ob_hat(i,1));
    %%
    %%% Original system
    theta=x1(i,1);
    dtheta=x2(i,1);
    Izz=m0*r0^2;
    M=Izz/4 + m0*((cos(theta/2)*(r0 - L/theta))/2 +...
        (L*sin(theta/2))/theta^2)^2 + (m0*sin(theta/2)^2*(r0 - L/theta)^2)/4;
    C_simp=-(L*dtheta*m0*(2*sin(theta/2) - theta*cos(theta/2))*(2*L*sin(theta/2)...
        - L*theta*cos(theta/2) + r0*theta^2*cos(theta/2)))/(2*theta^5);
    G_simp=-(g*m0*(L*sin(theta) + r0*theta^2*cos(theta) - L*theta*cos(theta)))/(2*theta^2);
    f=M\(-k*x1(i,1) -(b+C_simp)*x2(i,1)- G_simp);
    %%% State Estimate system
    theta_hat=x1_hat(i,1);
    dtheta_hat=x2_hat(i,1);
    Izz=m0*r0^2;
    M_hat=Izz/4 + m0*((cos(theta_hat/2)*(r0 - L/theta_hat))/2 +...
        (L*sin(theta_hat/2))/theta_hat^2)^2 + (m0*sin(theta_hat/2)^2*(r0 - L/theta_hat)^2)/4;
    C_simp_hat=-(L*dtheta_hat*m0*(2*sin(theta_hat/2) - theta_hat*cos(theta_hat/2))*(2*L*sin(theta_hat/2)...
        - L*theta_hat*cos(theta_hat/2) + r0*theta_hat^2*cos(theta_hat/2)))/(2*theta_hat^5);
    G_simp_hat=-(g*m0*(L*sin(theta_hat) + r0*theta_hat^2*cos(theta_hat) - L*theta_hat*cos(theta_hat)))/(2*theta_hat^2);
    f_x_hat=M_hat\(-k*x1_hat(i,1) -(b+C_simp_hat)*x2_hat(i,1)- G_simp_hat);
    %%%% Update raw control signal u_raw
    u_raw(i,1)=(1/(alpha/M_hat))*(smc_alpha_3*u_bar(i,1)-f_x_hat);
    
    %% Switch between bounded 
    if flag_input_bound==0
        % State feedback controller
        per_ob(i,1)=(-deltaK*x1(i,1)-deltaD*x2(i,1) + deltaAlpha*u_raw(i,1) + disturb(i,1))/M;
        dx1(i,1)=x2(i,1);
        dx2(i,1)=smc_alpha_3*u_bar(i,1)+per_ob(i,1);
        % State Observer
        dx1_hat(i,1)=x2_e(i,1)-smc_k1_epsil*smc_epsil*sign(x1_e(i,1));
        dx2_hat(i,1)=-smc_k2_epsil*smc_epsil*sign(x1_e(i,1))+ smc_alpha_3*u_bar(i,1)+per_ob_hat(i,1);
        dx3_hat(i,1)=smc_alpha_3^2*(-x3_hat(i,1)+smc_alpha_3*x2_hat(i,1)+u_bar(i,1));
    else
        %% Bound control signal
        pd1_MPa=(u_raw(i,1)/alpha-(0.5*sin(phi)+0.5*sqrt(3)*cos(phi))*pm2_MPa+sin(phi)*pm3_MPa)/(0.5*sin(phi)-0.5*sqrt(3)*cos(phi));
        if pd1_MPa > pd1_upperlimit_MPa
            u_bound(i,1)=(pd1_upperlimit_MPa*(0.5*sin(phi)-0.5*sqrt(3)*cos(phi))+(0.5*sin(phi)+0.5*sqrt(3)*cos(phi))*pm2_MPa+sin(phi)*pm3_MPa)*alpha;
        elseif pd1_MPa < pd1_lowerlimit_MPa
            u_bound(i,1)=(pd1_upperlimit_MPa*(0.5*sin(phi)-0.5*sqrt(3)*cos(phi))+(0.5*sin(phi)+0.5*sqrt(3)*cos(phi))*pm2_MPa+sin(phi)*pm3_MPa)*alpha;
        else
            u_bound(i,1)=u_raw(i,1);
        end
        % State feedback controller
        per_ob(i,1)=(+deltaK*x1(i,1)+ deltaD*x2(i,1) + deltaAlpha*u_bound(i,1) + disturb(i,1))/M;
        dx1(i,1)=x2(i,1);
%         dx2(i,1)=u_bound(i,1)*(alpha/M)+f+per_ob(i,1);
        dx2(i,1)=u_bound(i,1)*(alpha/M_hat)+f_x_hat+per_ob(i,1);
        % State Observer
        dx1_hat(i,1)=x2_e(i,1)-smc_k1_epsil*smc_epsil*sign(x1_e(i,1));
        dx2_hat(i,1)=-smc_k2_epsil*smc_epsil*sign(x1_e(i,1))+ u_bound(i,1)*(alpha/M_hat)+f_x_hat+per_ob_hat(i,1);
        dx3_hat(i,1)=smc_alpha_3^2*(-x3_hat(i,1)+smc_alpha_3*x2_hat(i,1)+ (u_bound(i,1)*(alpha/M_hat)+f_x_hat)/smc_alpha_3);
    end
    %% Update State Variable
    x1(i+1,1)=x1(i,1)+dx1(i,1)*Ts;
    x2(i+1,1)=x2(i,1)+dx2(i,1)*Ts;
    x1_hat(i+1,1)=x1_hat(i,1)+dx1_hat(i,1)*Ts;
    x2_hat(i+1,1)=x2_hat(i,1)+dx2_hat(i,1)*Ts;
    x3_hat(i+1,1)=x3_hat(i,1)+dx3_hat(i,1)*Ts;
end
%% Result compare
close all
if flag_input_bound==0
figure(1)
subplot(3,1,1)
plot(timeArray(2:end),xd(2:end),'r')
hold on
plot(timeArray(2:end),x1(2:end),'b')
legend('ref','x1')
ylim([-5,5])
title(['Unbonded Control Signal with'...
    ' \Delta k =',num2str(deltaK),' \Delta d =',num2str(deltaD),' \Delta \alpha=',num2str(deltaAlpha),'\lambda_d=',num2str(smc_lambda_d)])
ylabel('Angle(rad)')
hold on
subplot(3,1,2)
plot(timeArray(2:end),u_raw(2:end),'r')
hold on
title(['Control Signal u'])
ylabel('Torque(N\cdotm)')
xlabel('time')
subplot(3,1,3)
plot(timeArray(2:end),per_ob(2:end),'r')
hold on
plot(timeArray(2:end),per_ob_hat(2:end),'b')
legend('\Psi','\Psi_{est}')
title(['Perterbation Estimation'])
ylabel('Torque(N\cdotm)')
xlabel('time')
else
figure(1)
subplot(3,1,1)
plot(timeArray(2:end),xd(2:end),'r')
hold on
plot(timeArray(2:end),x1(2:end),'b')
legend('ref','x1')
ylim([-5,5])
title(['Bonded Control Signal with'...
    ' \Delta k =',num2str(deltaK),' \Delta d =',num2str(deltaD),' \Delta \alpha=',num2str(deltaAlpha),'\lambda_d=',num2str(smc_lambda_d)])
ylabel('Angle(rad)')
hold on
subplot(3,1,2)
plot(timeArray(2:end),u_bound(2:end),'r')
title(['Control Signal u'])
ylim([-0.5,0.5])
ylabel('Torque(N\cdotm)')
xlabel('time')
subplot(3,1,3)
plot(timeArray(2:end),per_ob(2:end),'r')
hold on
plot(timeArray(2:end),per_ob_hat(2:end),'b')
legend('\Psi','\Psi_{est}')
title(['Perterbation Estimation'])
ylabel('Torque(N\cdotm)')
xlabel('time')
end
end