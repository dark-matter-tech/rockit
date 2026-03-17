#include <cstdio>
#include <cstdint>

struct Node {
    Node* left;
    Node* right;
};

Node* bottomUpTree(int depth) {
    Node* n = new Node();
    if (depth > 0) {
        n->left = bottomUpTree(depth - 1);
        n->right = bottomUpTree(depth - 1);
    } else {
        n->left = nullptr;
        n->right = nullptr;
    }
    return n;
}

int64_t itemCheck(Node* node) {
    if (node->left == nullptr) return 1;
    return 1 + itemCheck(node->left) + itemCheck(node->right);
}

void deleteTree(Node* node) {
    if (node->left != nullptr) {
        deleteTree(node->left);
        deleteTree(node->right);
    }
    delete node;
}

int main() {
    int n = 21;
    int minDepth = 4;
    int maxDepth = n;
    if (minDepth + 2 > n) maxDepth = minDepth + 2;
    int stretchDepth = maxDepth + 1;

    Node* stretchTree = bottomUpTree(stretchDepth);
    printf("stretch tree of depth %d\t check: %lld\n", stretchDepth, itemCheck(stretchTree));
    deleteTree(stretchTree);

    Node* longLivedTree = bottomUpTree(maxDepth);

    for (int depth = minDepth; depth <= maxDepth; depth += 2) {
        int iterations = 1 << (maxDepth - depth + minDepth);
        int64_t check = 0;
        for (int i = 0; i < iterations; i++) {
            Node* tree = bottomUpTree(depth);
            check += itemCheck(tree);
            deleteTree(tree);
        }
        printf("%d\t trees of depth %d\t check: %lld\n", iterations, depth, check);
    }

    printf("long lived tree of depth %d\t check: %lld\n", maxDepth, itemCheck(longLivedTree));
    deleteTree(longLivedTree);
    return 0;
}
