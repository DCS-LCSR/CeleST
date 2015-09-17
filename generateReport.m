function generateReport(varargin)

global filenames startTime fileLogID;

% if nargin > 1
    % Let log know user is sending report at time
    disp(['CeleST user report at ' datestr(clock)]);
    
    errName = 'Send Report about bug, behavioral issue, or send a suggestion';
    instructions = ['If you encountered a bug, system froze, or some other behavioral issue, '...
    'please include which window you were working with and/or what you were doing when the problem occurred. '...
    'Otherwise feel free to send a suggestion'];
    
    message = 'User Report';
% else
%     % Clean-up CeleST couldn't do, due to error
%     disp(['CeleST error at ' datestr(clock)]);
%     diary off
%     % Get error report
%     errEncountered = getReport(varargin{1}, 'extended', 'hyperlinks', 'off');
%     
%     errName = 'Report System Error';
%     instructions = ['An error has occurred. Please type a brief message describing what you were doing prior to the error. '...
%         'Some useful information may include which window you were using or what was pressed prior to the error'];
%     
%     message = ['Error Stack:' 10 errEncountered];
% end

% Error Reporting Window appears when error is caught
errWindow = figure('Name', errName, 'NumberTitle', 'off','Menubar', 'none', 'Position', [100 100 650 500], 'Visible', 'off');
uicontrol(errWindow, 'Style', 'text', 'String', 'Sender Name', 'Position', [50 365 100 30]);
errSender = uicontrol(errWindow, 'Style', 'edit', 'Position', [160 370 365 30]);
uicontrol(errWindow, 'Style', 'text', 'String', instructions, 'Position', [50 410 550 70]);
errMessage = uicontrol(errWindow, 'Style', 'edit', 'Position', [50 85 550 275]);
uicontrol(errWindow, 'Style', 'pushbutton', 'String', 'Send', 'Position', [75 20 225 50], 'Callback', @SendReport);
uicontrol(errWindow, 'Style', 'pushbutton', 'String', 'Cancel', 'Position', [325 20 250 50], 'Callback', @DontSend);

set(errWindow, 'Visible', 'on');
waitfor(errWindow, 'BeingDeleted','on');

    function SendReport(~, ~)
        % Check for Blank Textbox
        if isempty(get(errMessage, 'String'))
            answer = questdlg('Are you sure you want to send the report with no body in the message?', 'Empty Body Encountered', 'Yes', 'No', 'No');
            if strcmp(answer,'No')
                return
            end
        end
        
        % Setup
        [sender,passphrase,recipients] = getEmailInfo();
        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','E_mail',sender);
        setpref('Internet','SMTP_Username',sender);
        setpref('Internet','SMTP_Password',passphrase);
        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
        props.setProperty('mail.smtp.socketFactory.port','465');
        
        % Create Message
        message = [message 10 10 'User message:' 10 get(errMessage, 'String')];
        
        % Get Attachments
        attachments = {[filenames.log '/comWinLog'],fileLogID};
        
        % Send Mail
        try
            if isempty(get(errSender, 'String'))
                sender = '';
            else
                sender =  [' from ' get(errSender, String)];
            end
            sendmail(recipients,['CeleST Bug Report on ' startTime sender], message, attachments);
        catch
            msgbox('Report could not be sent, please check your internet connection')
        end
        close(errWindow);
    end
    function DontSend(~, ~)
        close(errWindow);
    end
    function [sender, passphrase, recipients] = getEmailInfo()
        configFID = fopen([filenames.curr '/CeleST/bugreportinfo']);
        configInfo = textscan(configFID, '%s', 'delimiter', '\n');
        configInfo = configInfo{1};
        sender = configInfo{1};
        passphrase = configInfo{2};
        recipients = '';
        if length(configInfo) > 2
            recipients = configInfo(3:end);
        end
    end
end