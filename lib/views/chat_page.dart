import 'dart:math';

import 'package:clipboard/clipboard.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter/material.dart';
import 'package:openchat_frontend/main.dart';
import 'package:openchat_frontend/repository/ws_chat_manager.dart';
import 'package:openchat_frontend/utils/account_provider.dart';
import 'package:local_hero/local_hero.dart';
import 'package:openchat_frontend/model/chat.dart';
import 'package:openchat_frontend/repository/repository.dart';
import 'package:openchat_frontend/utils/dialog.dart';
import 'package:openchat_frontend/views/components/animated_text.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:openchat_frontend/views/components/chat_ui/flutter_chat_ui.dart';
import 'package:openchat_frontend/views/components/delay_show_button.dart';
import 'package:openchat_frontend/views/components/intro.dart';
import 'package:openchat_frontend/views/components/typing_indicator.dart';
import 'package:openchat_frontend/views/components/widgets.dart';
import 'package:openchat_frontend/views/history_page.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

const user = types.User(id: 'user');
const reply = types.User(id: 'moss');

const kTabletMasterContainerWidth = 370.0;
const kTabletSingleContainerWidth = 480.0;

bool isDesktop(BuildContext context) {
  return MediaQuery.of(context).size.width >= 768.0;
}

class ChatView extends StatefulWidget {
  final ChatThread topic;
  final bool showMenu;
  const ChatView({super.key, required this.topic, this.showMenu = false});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final GlobalKey<ChatState> _chatKey = GlobalKey();
  final List<types.Message> _messages = [];

  late final WebSocketChatManager chatManager;

  bool interacted =
      false; // Whether user has interacted with the chat in this session

  bool isFirstResponse = true;
  bool isStreamingResponse = false;

  bool lateInitDone = false;

  void lateInit() {
    lateInitDone = true;
    _messages.clear();
    _getRecords();
    chatManager = WebSocketChatManager(
      widget.topic.id,
      Provider.of<AccountProvider>(context).token!,
      onAddRecord: (record) {
        final provider = Provider.of<AccountProvider>(context, listen: false);
        if (widget.topic.records!.isEmpty) {
          // Handle first record: change title and add warning message
          provider.user!.chats!
                  .firstWhere((element) => element.id == widget.topic.id)
                  .name =
              record.request.substring(0, min(30, record.request.length));
        }
        widget.topic.records!.add(record);
      },
      onDone: () {
        if (mounted) {
          setState(() {
            isStreamingResponse = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          isStreamingResponse = false;
          setState(() {
            if (!isFirstResponse) {
              // A message has already been created, it must be deleted
              _messages.removeAt(0);
              isFirstResponse = true;
            }
            _messages.insert(
                0,
                types.SystemMessage(
                  text: parseError(error),
                  id: "${widget.topic.id}ai-error${_messages.length}",
                ));
          });
        }
      },
      onReceive: (event) {
        if (isFirstResponse) {
          isFirstResponse = false;
          if (mounted) {
            setState(() {
              _messages.insert(
                  0,
                  types.TextMessage(
                      author: reply,
                      text: event,
                      // ignore: prefer_const_literals_to_create_immutables
                      metadata: {'animatedIndex': 0, 'currentText': event},
                      id: _messages.length.toString(),
                      type: types.MessageType.text));
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _messages.first.metadata!['currentText'] = event;
            });
          }
        }
      },
    );
  }

  @override
  void dispose() {
    chatManager.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!lateInitDone) {
      lateInit();
    }
  }

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic.id != widget.topic.id) {
      lateInit();
    }
  }

  Future<void> _getRecords() async {
    try {
      widget.topic.records ??=
          await Repository.getInstance().getChatRecords(widget.topic.id);
      if (widget.topic.records!.isNotEmpty) {
        setState(() {
          _messages.insert(
              0,
              types.SystemMessage(
                text: "",
                id: "${widget.topic.id}hack",
              ));
        });
        await Future.delayed(
            const Duration(milliseconds: 100)); // A hack to let animations run
        _messages.insert(
            0,
            types.SystemMessage(
              text: AppLocalizations.of(context)!.aigc_warning_message,
              id: "${widget.topic.id}ai-alert",
            ));
      }
      for (final record in widget.topic.records!) {
        _messages.insert(
            0,
            types.TextMessage(
              id: "${widget.topic.id}-${record.id}",
              text: record.request,
              author: user,
              // ignore: prefer_const_literals_to_create_immutables
              metadata: {'animatedIndex': record.request.length},
            ));
        _messages.insert(
            0,
            types.TextMessage(
              id: "${widget.topic.id}-${record.id}r",
              text: record.response,
              author: reply,
              // ignore: prefer_const_literals_to_create_immutables
              metadata: {'animatedIndex': record.response.length},
            ));
      }
    } catch (e) {
      _messages.insert(
          0,
          types.SystemMessage(
            text: parseError(e),
            id: "${widget.topic.id}ai-error${_messages.length}",
          ));
    } finally {
      setState(() {});
    }
  }

  bool get isWaitingForResponse =>
      (_messages.firstOrNull?.author.id == user.id) || isStreamingResponse;

  bool get shouldUseLargeLogo {
    if (_messages.isNotEmpty) {
      return false;
    }
    if (widget.topic.records == null) {
      return widget.topic.name.isEmpty ||
          widget.topic.name == AppLocalizations.of(context)!.untitled_topic;
    }
    return widget.topic.records!.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: (widget.showMenu)
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => HistoryPage(
                          selectedTopic: widget.topic,
                          onTopicSelected: (p0) {
                            TopicStateProvider.getInstance().currentTopic = p0;
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ))
            : null,
        title: shouldUseLargeLogo
            ? const SizedBox()
            : LocalHero(
                tag:
                    "MossLogo${isDesktop(context) ? "Desktop" : widget.topic.id}}",
                child: Image.asset('assets/images/logo.webp', scale: 7)),
        surfaceTintColor: Colors.transparent,
      ),
      body: Chat(
        key: _chatKey,
        messages: _messages,
        user: user,
        showUserAvatars: false,
        inputOptions: const InputOptions(
            inputClearMode: InputClearMode.never,
            sendButtonVisibilityMode: SendButtonVisibilityMode.always),
        theme: DefaultChatTheme(
          primaryColor: themeColor,
          backgroundColor: Theme.of(context).colorScheme.surface,
          inputBackgroundColor: Theme.of(context).colorScheme.secondary,
          inputTextCursorColor: Theme.of(context).colorScheme.onSecondary,
          inputTextColor: Theme.of(context).colorScheme.onSecondary,
          inputBorderRadius: const BorderRadius.all(Radius.circular(8)),
          inputMargin: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          sentMessageSelectionColor: const Color(0x7fdda0dd),
          receivedMessageSelectionColor: null,
        ),
        emptyState: shouldUseLargeLogo
            ? MossIntroWidget(
                heroTag:
                    "MossLogo${isDesktop(context) ? "Desktop" : widget.topic.id}}",
              )
            : const SizedBox(),
        customBottomWidget: const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 12, right: 12),
            child: ShareInfoConsentWidget()),
        onSendPressed:
            (types.PartialText message, VoidCallback clearInput) async {
          if (isWaitingForResponse || widget.topic.records == null) return;
          interacted = true;
          final topic = widget.topic;
          final provider = Provider.of<AccountProvider>(context, listen: false);
          clearInput();
          setState(() {
            if (_messages.isEmpty) {
              _messages.insert(
                  0,
                  types.SystemMessage(
                    text: AppLocalizations.of(context)!.aigc_warning_message,
                    id: "${widget.topic.id}ai-alert",
                  ));
            }
            _messages.insert(
                0,
                types.TextMessage(
                    author: user,
                    text: message.text,
                    // ignore: prefer_const_literals_to_create_immutables
                    metadata: {'animatedIndex': 0},
                    id: _messages.length.toString(),
                    type: types.MessageType.text));
          });
          try {
            isFirstResponse = true;
            isStreamingResponse = true;
            chatManager.sendMessage(message.text);
          } catch (e) {
            if (mounted) {
              setState(() {
                _messages.insert(
                    0,
                    types.SystemMessage(
                      text: parseError(e),
                      id: "ai-error${_messages.length}",
                    ));
              });
            }
          }
        },
        listBottomWidget: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // New Topic Button
              DelayShowWidget(
                delay: const Duration(seconds: 5),
                enabled: interacted,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HistoryPageState.addNewTopic(null);
                    },
                    icon: Icon(Icons.add,
                        color: Theme.of(context).colorScheme.secondary),
                    label: Text(
                      AppLocalizations.of(context)!.new_topic,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ),
              ),
              // Reaction Bar
              (_messages.firstOrNull?.author.id != user.id &&
                      _messages.firstOrNull?.author.id != reply.id)
                  ? const SizedBox(height: 40)
                  : AnimatedCrossFade(
                      crossFadeState: isWaitingForResponse
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 200),
                      firstChild: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: const [TypingIndicator()]),
                      secondChild: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TextButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: Text(
                                  AppLocalizations.of(context)!.regenerate),
                              onPressed: () async {
                                final topic = widget.topic;
                                setState(() {
                                  _messages.removeAt(0);
                                  topic.records!.removeLast();
                                });
                                try {
                                  isFirstResponse = true;
                                  isStreamingResponse = true;
                                  chatManager.regenerate();
                                } catch (e) {
                                  if (mounted) {
                                    setState(() {
                                      _messages.insert(
                                          0,
                                          types.SystemMessage(
                                            text: parseError(e),
                                            id: "ai-error${_messages.length}",
                                          ));
                                    });
                                  }
                                }
                              }),
                          IconButton(
                            icon: Icon(Icons.thumb_up,
                                size: 16,
                                color: widget.topic.records!.lastOrNull
                                            ?.like_data ==
                                        1
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .buttonTheme
                                        .colorScheme
                                        ?.onSurface
                                        .withAlpha(130)),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              if (widget.topic.records?.isEmpty != false)
                                return;
                              int newLike = 1;
                              if (widget.topic.records!.last.like_data ==
                                  newLike) {
                                newLike = 0;
                              }
                              try {
                                await Repository.getInstance().modifyRecord(
                                    widget.topic.records!.last.id, newLike);
                                setState(() {
                                  widget.topic.records!.last.like_data =
                                      newLike;
                                });
                              } catch (e) {
                                await showAlert(context, parseError(e),
                                    AppLocalizations.of(context)!.error);
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.thumb_down,
                                size: 16,
                                color: widget.topic.records!.lastOrNull
                                            ?.like_data ==
                                        -1
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .buttonTheme
                                        .colorScheme
                                        ?.onSurface
                                        .withAlpha(130)),
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              if (widget.topic.records?.isEmpty != false)
                                return;
                              int newLike = -1;
                              if (widget.topic.records!.last.like_data ==
                                  newLike) {
                                newLike = 0;
                              }
                              try {
                                await Repository.getInstance().modifyRecord(
                                    widget.topic.records!.last.id, newLike);
                                setState(() {
                                  widget.topic.records!.last.like_data =
                                      newLike;
                                });
                              } catch (e) {
                                await showAlert(context, parseError(e),
                                    AppLocalizations.of(context)!.error);
                              }
                            },
                          ),
                          const Spacer(),
                          IconButton(
                              onPressed: () {
                                String content = "";
                                for (final record in widget.topic.records!) {
                                  content += "[User]\n${record.request}\n\n";
                                  content += "[MOSS]\n${record.response}\n\n";
                                }
                                FlutterClipboard.copy(content);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            AppLocalizations.of(context)!
                                                .copied_to_clipboard)));
                              },
                              icon: const Icon(Icons.copy_all)),
                          IconButton(
                              onPressed: () async {
                                try {
                                  final String url =
                                      (await Repository.getInstance()
                                          .getScreenshotForChat(
                                              widget.topic.id))!;
                                  await launchUrlString(url);
                                } catch (e) {
                                  await showAlert(context, parseError(e),
                                      AppLocalizations.of(context)!.error);
                                }
                              },
                              icon: const Icon(Icons.share)),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        textMessageBuilder: (msg, {required messageWidth, required showName}) {
          return AnimatedTextMessage(
              message: msg, speed: 20, animate: msg.author.id == reply.id);
        },
      ),
    );
  }
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  // Mobile UI
  Widget buildMobile(BuildContext context) =>
      Selector<TopicStateProvider, ChatThread?>(
          selector: (_, model) => model.currentTopic,
          builder: (context, value, child) => value == null
              ? NullChatLoader(
                  heroTag:
                      "MossLogo${isDesktop(context) ? "Desktop" : value?.id}}",
                )
              : ChatView(key: ValueKey(value), topic: value, showMenu: true));

  // Desktop UI
  Widget buildDesktop(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left View
          SizedBox(
            height: MediaQuery.of(context).size.height,
            width: kTabletMasterContainerWidth,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0)),
                clipBehavior: Clip.antiAlias,
                child: Selector<TopicStateProvider, ChatThread?>(
                    selector: (_, model) => model.currentTopic,
                    builder: (context, value, child) =>
                        HistoryPage(selectedTopic: value)),
              ),
            ),
          ),
          // Right View
          ScaffoldMessenger(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width -
                  kTabletMasterContainerWidth,
              child: SizedBox.expand(
                child: Card(
                  margin: const EdgeInsets.only(top: 16, right: 16, bottom: 16),
                  color: Theme.of(context).colorScheme.background,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0)),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: SizedBox(
                      width: min(
                          MediaQuery.of(context).size.height,
                          MediaQuery.of(context).size.width -
                              kTabletMasterContainerWidth),
                      child: Selector<TopicStateProvider, ChatThread?>(
                          selector: (_, model) => model.currentTopic,
                          builder: (context, value, child) => value == null
                              ? NullChatLoader(
                                  heroTag:
                                      "MossLogo${isDesktop(context) ? "Desktop" : value?.id}}",
                                )
                              : ChatView(key: ValueKey(value), topic: value)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LocalHeroScope(
      createRectTween: (begin, end) {
        return RectTween(begin: begin, end: end);
      },
      duration: const Duration(milliseconds: 700),
      curve: Curves.fastLinearToSlowEaseIn,
      child: isDesktop(context) ? buildDesktop(context) : buildMobile(context));
}
