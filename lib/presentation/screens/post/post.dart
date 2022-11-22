import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/hooks/extended_page_controller.dart';
import 'package:boorusphere/presentation/provider/booru/entity/fetch_result.dart';
import 'package:boorusphere/presentation/provider/booru/page_state.dart';
import 'package:boorusphere/presentation/provider/fullscreen.dart';
import 'package:boorusphere/presentation/provider/settings/content_settings.dart';
import 'package:boorusphere/presentation/screens/home/timeline/controller.dart';
import 'package:boorusphere/presentation/screens/post/hooks/precache_posts.dart';
import 'package:boorusphere/presentation/screens/post/post_error.dart';
import 'package:boorusphere/presentation/screens/post/post_image.dart';
import 'package:boorusphere/presentation/screens/post/post_toolbox.dart';
import 'package:boorusphere/presentation/screens/post/post_video.dart';
import 'package:boorusphere/presentation/widgets/slidefade_visibility.dart';
import 'package:boorusphere/presentation/widgets/styled_overlay_region.dart';
import 'package:boorusphere/utils/extensions/buildcontext.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class PostPage extends HookConsumerWidget {
  const PostPage({
    super.key,
    required this.beginPage,
    required this.controller,
  });

  final int beginPage;
  final TimelineController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const loadMoreThreshold = 90;
    final page = useState(beginPage);
    final pageController = useExtendedPageController(initialPage: page.value);
    final loadOriginal =
        ref.watch(contentSettingStateProvider.select((it) => it.loadOriginal));
    final pageState = ref.watch(pageStateProvider);
    final fullscreen = ref.watch(fullscreenStateProvider);
    final posts = ref.watch(pageStateProvider.select((it) => it.data.posts));

    final post = posts.isEmpty ? Post.empty : posts[page.value];
    final precachePosts = usePrecachePosts(ref, posts);

    return WillPopScope(
      onWillPop: () async {
        context.scaffoldMessenger.removeCurrentSnackBar();
        controller.revealAt(page.value);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: StyledOverlayRegion(
          nightMode: true,
          child: Stack(
            children: [
              Padding(
                // android back gesture is not ignored by PageView
                // add tiny padding to avoid it
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: ExtendedImageGesturePageView.builder(
                  controller: pageController,
                  onPageChanged: (index) {
                    context.scaffoldMessenger.hideCurrentSnackBar();
                    page.value = index;
                    final offset = index + 1;
                    final threshold =
                        posts.length / 100 * (100 - loadMoreThreshold);
                    if (offset + threshold > posts.length) {
                      controller.loadMoreData();
                    }
                  },
                  itemCount: posts.length,
                  itemBuilder: (_, index) {
                    precachePosts(index, loadOriginal);

                    final post = posts[index];
                    final Widget widget;
                    final heroKey =
                        controller.heroKeyBuilder?.call(post) ?? post.id;
                    switch (post.content.type) {
                      case PostType.photo:
                        widget = PostImageDisplay(
                          post: post,
                          isFromHome: index == beginPage,
                          heroKey: heroKey,
                        );
                        break;
                      case PostType.video:
                        widget = PostVideoDisplay(
                          post: post,
                          heroKey: heroKey,
                        );
                        break;
                      default:
                        widget = PostErrorDisplay(
                          post: post,
                          heroKey: heroKey,
                        );
                        break;
                    }
                    return HeroMode(
                      enabled: index == page.value,
                      child: widget,
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideFadeVisibility(
                  direction: HidingDirection.toTop,
                  visible: !fullscreen,
                  child: _PostAppBar(
                    subtitle: post.tags.join(' '),
                    title: pageState is LoadingFetchResult
                        ? '#${page.value + 1} of (loading...)'
                        : '#${page.value + 1} of ${posts.length}',
                  ),
                ),
              ),
              if (!post.content.isVideo)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideFadeVisibility(
                    direction: HidingDirection.toBottom,
                    visible: !fullscreen,
                    child: PostToolbox(post),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PostAppBar({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w300),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 64);
}
